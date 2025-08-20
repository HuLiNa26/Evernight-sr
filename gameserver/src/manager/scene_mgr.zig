const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("../services/config.zig");
const Res_config = @import("../services/res_config.zig");
const Item = @import("../services/item.zig");
const UidGenerator = Item.UidGenerator();
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const CmdID = protocol.CmdID;

pub const SceneManager = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) SceneManager {
        return SceneManager{ .allocator = allocator };
    }

    fn addAvatarEntities(
        scene_group: *protocol.SceneEntityGroupInfo,
        avatar_configs: []const Config.Avatar,
        tele_pos: protocol.Vector,
        tele_rot: protocol.Vector,
        uid: u32,
    ) !void {
        for (avatar_configs) |avatarConf| {
            try scene_group.entity_list.append(.{
                .inst_id = 1,
                .entity_id = @intCast(avatarConf.id + 100000),
                .actor = .{
                    .base_avatar_id = avatarConf.id,
                    .avatar_type = .AVATAR_FORMAL_TYPE,
                    .uid = uid,
                    .map_layer = 0,
                },
                .motion = .{ .pos = tele_pos, .rot = tele_rot },
            });
        }
    }
    fn addPropEntities(
        allocator: Allocator,
        group_map: *std.AutoHashMap(u32, protocol.SceneEntityGroupInfo),
        prop_configs: []const Res_config.Props,
        generator: *UidGenerator,
    ) !void {
        for (prop_configs) |propConf| {
            var scene_group = try getOrCreateGroup(group_map, propConf.groupId, allocator);
            var prop_info = protocol.ScenePropInfo.init(allocator);
            prop_info.prop_id = propConf.propId;
            prop_info.prop_state = propConf.propState;
            try scene_group.entity_list.append(.{
                .prop = prop_info,
                .group_id = scene_group.group_id,
                .inst_id = propConf.instId,
                .entity_id = 1000 + generator.nextId(),
                .motion = .{
                    .pos = .{ .x = propConf.pos.x, .y = propConf.pos.y, .z = propConf.pos.z },
                    .rot = .{ .x = propConf.rot.x, .y = propConf.rot.y, .z = propConf.rot.z },
                },
            });
        }
    }
    fn addMonsterEntities(
        allocator: Allocator,
        group_map: *std.AutoHashMap(u32, protocol.SceneEntityGroupInfo),
        monster_configs: []const Res_config.Monsters,
        generator: *UidGenerator,
    ) !void {
        for (monster_configs) |monsConf| {
            var scene_group = try getOrCreateGroup(group_map, monsConf.groupId, allocator);
            var monster_info = protocol.SceneNpcMonsterInfo.init(allocator);
            monster_info.monster_id = monsConf.monsterId;
            monster_info.event_id = monsConf.eventId;
            monster_info.world_level = 6;
            try scene_group.entity_list.append(.{
                .npc_monster = monster_info,
                .group_id = scene_group.group_id,
                .inst_id = monsConf.instId,
                .entity_id = if ((monsConf.monsterId / 1000) % 10 == 3) monster_info.monster_id else generator.nextId(),
                .motion = .{
                    .pos = .{ .x = monsConf.pos.x, .y = monsConf.pos.y, .z = monsConf.pos.z },
                    .rot = .{ .x = monsConf.rot.x, .y = monsConf.rot.y, .z = monsConf.rot.z },
                },
            });
        }
    }
    pub fn createScene(
        self: *SceneManager,
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        teleport_id: u32,
    ) !protocol.SceneInfo {
        const config = try Config.loadGameConfig(self.allocator, "config.json");
        const res_config = global_game_config_cache.res_config;
        var generator = Item.UidGenerator().init();

        var scene_info = protocol.SceneInfo.init(self.allocator);
        scene_info.game_mode_type = 1;
        scene_info.plane_id = plane_id;
        scene_info.floor_id = floor_id;
        scene_info.entry_id = entry_id;
        scene_info.leader_entity_id = config.avatar_config.items[0].id + 100000;
        scene_info.world_id = 501;
        scene_info.client_pos_version = 1;

        var group_map = std.AutoHashMap(u32, protocol.SceneEntityGroupInfo).init(self.allocator);
        defer group_map.deinit();

        for (res_config.scene_config.items) |sceneConf| {
            for (sceneConf.teleports.items) |teleConf| {
                if (teleConf.teleportId == teleport_id) {
                    var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
                    scene_group.state = 1;
                    const proto_tele_pos = protocol.Vector{
                        .x = teleConf.pos.x,
                        .y = teleConf.pos.y,
                        .z = teleConf.pos.z,
                    };
                    const proto_tele_rot = protocol.Vector{
                        .x = teleConf.rot.x,
                        .y = teleConf.rot.y,
                        .z = teleConf.rot.z,
                    };

                    try addAvatarEntities(&scene_group, config.avatar_config.items, proto_tele_pos, proto_tele_rot, 0);
                    try scene_info.entity_group_list.append(scene_group);
                    break;
                }
            }
            if (sceneConf.planeID == scene_info.plane_id and sceneConf.entryID == scene_info.entry_id) {
                try addPropEntities(self.allocator, &group_map, sceneConf.props.items, &generator);
                try addMonsterEntities(self.allocator, &group_map, sceneConf.monsters.items, &generator);
            }
        }

        var iter = group_map.iterator();
        while (iter.next()) |entry| {
            try scene_info.entity_group_list.append(entry.value_ptr.*);
            try scene_info.entity_list.appendSlice(entry.value_ptr.entity_list.items);
            try scene_info.DJBIBIJMEBH.append(entry.value_ptr.group_id);
            try scene_info.custom_data_list.append(protocol.CustomSaveData{
                .group_id = entry.value_ptr.group_id,
            });
            try scene_info.group_state_list.append(protocol.SceneGroupState{
                .group_id = entry.value_ptr.group_id,
                .state = 0,
                .is_default = true,
            });
        }
        const ranges = [_][2]usize{
            .{ 0, 101 },
            .{ 10000, 10051 },
            .{ 20000, 20001 },
            .{ 30000, 30020 },
        };
        for (ranges) |range| {
            for (range[0]..range[1]) |i| {
                try scene_info.lighten_section_list.append(@intCast(i));
            }
        }
        return scene_info;
    }
    fn getOrCreateGroup(group_map: *std.AutoHashMap(u32, protocol.SceneEntityGroupInfo), group_id: u32, allocator: Allocator) !*protocol.SceneEntityGroupInfo {
        if (group_map.getPtr(group_id)) |existing_group| {
            return existing_group;
        }
        var new_group = protocol.SceneEntityGroupInfo.init(allocator);
        new_group.state = 1;
        new_group.group_id = group_id;
        try group_map.put(group_id, new_group);
        return group_map.getPtr(group_id).?;
    }
};

pub const ChallengeSceneManager = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) ChallengeSceneManager {
        return ChallengeSceneManager{ .allocator = allocator };
    }
    pub fn getAnchorMotion(entry_id: u32) ?protocol.MotionInfo {
        const anchor_configs = global_game_config_cache.anchor_config.anchor_config.items;

        for (anchor_configs) |anchorConf| {
            if (anchorConf.entryID == entry_id) {
                if (anchorConf.anchor.items.len > 0) {
                    const anchor = anchorConf.anchor.items[0];
                    return protocol.MotionInfo{
                        .pos = .{ .x = anchor.pos.x, .y = anchor.pos.y, .z = anchor.pos.z },
                        .rot = .{ .x = anchor.rot.x, .y = anchor.rot.y, .z = anchor.rot.z },
                    };
                }
                break;
            }
        }
        return null;
    }
    fn createBaseScene(
        self: *ChallengeSceneManager,
        game_mode_type: u32,
        avatar_list: ArrayList(u32),
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        world_id: ?u32,
        maze_group_id: u32,
    ) !protocol.SceneInfo {
        var scene_info = protocol.SceneInfo.init(self.allocator);
        scene_info.game_mode_type = game_mode_type;
        scene_info.plane_id = plane_id;
        scene_info.floor_id = floor_id;
        scene_info.entry_id = entry_id;
        scene_info.leader_entity_id = avatar_list.items[0];
        if (world_id) |wid| scene_info.world_id = wid;

        try scene_info.group_state_list.append(protocol.SceneGroupState{
            .group_id = maze_group_id,
            .is_default = true,
        });
        var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
        scene_group.state = 1;
        scene_group.group_id = 0;
        for (avatar_list.items) |avatar_base_id| {
            try scene_group.entity_list.append(.{
                .inst_id = 1,
                .entity_id = @intCast(avatar_base_id + 100000),
                .actor = .{
                    .base_avatar_id = avatar_base_id,
                    .avatar_type = .AVATAR_FORMAL_TYPE,
                    .uid = 1,
                    .map_layer = 0,
                },
                .motion = .{ .pos = .{}, .rot = .{} },
            });
        }
        try scene_info.entity_group_list.append(scene_group);
        return scene_info;
    }
    fn addChallengeEntities(
        self: *ChallengeSceneManager,
        scene_info: *protocol.SceneInfo,
        group_id: u32,
        monster_id: u32,
        event_id: u32,
        generator: *UidGenerator,
    ) !void {
        const res_config = global_game_config_cache.res_config;
        for (res_config.scene_config.items) |sceneConf| {
            if (sceneConf.planeID == scene_info.plane_id) {
                for (sceneConf.monsters.items) |monsConf| {
                    if (monsConf.groupId == group_id) {
                        var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
                        scene_group.state = 1;
                        scene_group.group_id = group_id;
                        var monster_info = protocol.SceneNpcMonsterInfo.init(self.allocator);
                        monster_info.monster_id = monster_id;
                        monster_info.event_id = event_id;
                        monster_info.world_level = 6;
                        try scene_group.entity_list.append(.{
                            .npc_monster = monster_info,
                            .group_id = group_id,
                            .inst_id = monsConf.instId,
                            .entity_id = generator.nextId(),
                            .motion = .{
                                .pos = .{ .x = monsConf.pos.x, .y = monsConf.pos.y, .z = monsConf.pos.z },
                                .rot = .{ .x = monsConf.rot.x, .y = monsConf.rot.y, .z = monsConf.rot.z },
                            },
                        });
                        try scene_info.entity_group_list.append(scene_group);
                        break;
                    }
                }
                for (sceneConf.props.items) |propConf| {
                    if (propConf.groupId == group_id) {
                        var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
                        scene_group.state = 1;
                        scene_group.group_id = group_id;
                        var prop_info = protocol.ScenePropInfo.init(self.allocator);
                        prop_info.prop_id = propConf.propId;
                        prop_info.prop_state = propConf.propState;
                        try scene_group.entity_list.append(.{
                            .prop = prop_info,
                            .group_id = group_id,
                            .inst_id = propConf.instId,
                            .entity_id = generator.nextId(),
                            .motion = .{
                                .pos = .{ .x = propConf.pos.x, .y = propConf.pos.y, .z = propConf.pos.z },
                                .rot = .{ .x = propConf.rot.x, .y = propConf.rot.y, .z = propConf.rot.z },
                            },
                        });
                        try scene_info.entity_group_list.append(scene_group);
                    }
                }
            }
        }
    }

    pub fn createScene(
        self: *ChallengeSceneManager,
        avatar_list: ArrayList(u32),
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        world_id: u32,
        monster_id: u32,
        event_id: u32,
        group_id: u32,
        maze_group_id: u32,
    ) !protocol.SceneInfo {
        var scene_info = try self.createBaseScene(4, avatar_list, plane_id, floor_id, entry_id, world_id, maze_group_id);
        var generator = Item.UidGenerator().init();
        try self.addChallengeEntities(&scene_info, group_id, monster_id, event_id, &generator);
        return scene_info;
    }

    pub fn createPeakScene(
        self: *ChallengeSceneManager,
        avatar_list: ArrayList(u32),
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        monster_id: u32,
        event_id: u32,
        group_id: u32,
        maze_group_id: u32,
    ) !protocol.SceneInfo {
        var scene_info = try self.createBaseScene(4, avatar_list, plane_id, floor_id, entry_id, null, maze_group_id);
        var generator = Item.UidGenerator().init();
        try self.addChallengeEntities(&scene_info, group_id, monster_id, event_id, &generator);
        return scene_info;
    }
};
pub const MazeMapManager = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) MazeMapManager {
        return MazeMapManager{ .allocator = allocator };
    }

    pub fn setMazeMapData(
        self: *MazeMapManager,
        map_info: *protocol.SceneMapInfo,
        floor_id: u32,
    ) !void {
        const map_entrance_config = global_game_config_cache.map_entrance_config;
        const res_config = global_game_config_cache.res_config;

        var plane_ids_map = std.AutoHashMap(u32, void).init(self.allocator);
        defer plane_ids_map.deinit();

        for (map_entrance_config.map_entrance_config.items) |entrConf| {
            if (entrConf.floor_id == floor_id) {
                try plane_ids_map.put(entrConf.plane_id, {});
            }
        }

        map_info.maze_group_list = ArrayList(protocol.MazeGroup).init(self.allocator);
        map_info.maze_prop_list = ArrayList(protocol.MazePropState).init(self.allocator);

        for (res_config.scene_config.items) |sceneConf| {
            if (plane_ids_map.contains(sceneConf.planeID)) {
                for (sceneConf.props.items) |propConf| {
                    try map_info.maze_group_list.append(protocol.MazeGroup{
                        .NOBKEONAKLE = ArrayList(u32).init(self.allocator),
                        .group_id = propConf.groupId,
                    });
                    try map_info.maze_prop_list.append(protocol.MazePropState{
                        .group_id = propConf.groupId,
                        .config_id = propConf.instId,
                        .state = propConf.propState,
                    });
                }
            }
        }
    }
};
pub const GameConfigCache = struct {
    allocator: Allocator,
    res_config: Res_config.SceneConfig,
    map_entrance_config: Config.MapEntranceConfig,
    stage_config: Config.StageConfig,
    anchor_config: Res_config.SceneAnchorConfig,
    quest_config: Config.QuestConfig,

    pub fn init(allocator: Allocator) !GameConfigCache {
        const res_cfg = try Res_config.anchorLoader(allocator, "resources/res.json");
        const map_entr_cfg = try Config.loadMapEntranceConfig(allocator, "resources/MapEntrance.json");
        const stage_cfg = try Config.loadStageConfig(allocator, "resources/StageConfig.json");
        const anchor_cfg = try Res_config.anchorconfigLoader(allocator, "resources/Anchor.json");
        const quest_cfg = try Config.loadQuestConfig(allocator, "resources/QuestData.json");

        return GameConfigCache{
            .allocator = allocator,
            .res_config = res_cfg,
            .map_entrance_config = map_entr_cfg,
            .stage_config = stage_cfg,
            .anchor_config = anchor_cfg,
            .quest_config = quest_cfg,
        };
    }
    pub fn deinit(self: *GameConfigCache) void {
        self.res_config.deinit();
        self.map_entrance_config.deinit();
        self.stage_config.deinit();
        self.anchor_config.deinit();
        self.quest_config.deinit();
    }
};

pub var global_game_config_cache: GameConfigCache = undefined;
pub var global_main_allocator: Allocator = undefined;

pub fn initGameGlobals(main_allocator: Allocator) !void {
    global_main_allocator = main_allocator;
    global_game_config_cache = try GameConfigCache.init(main_allocator);
}

pub fn deinitGameGlobals() void {
    global_game_config_cache.deinit();
}
