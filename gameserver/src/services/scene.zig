const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const log = std.log.scoped(.scene_service);

pub fn onGetCurSceneInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(20422, 20422001, 2042201, 1025);
    try session.send(CmdID.CmdGetCurSceneInfoScRsp, protocol.GetCurSceneInfoScRsp{
        .scene = scene_info,
        .retcode = 0,
    });
}
pub fn onSceneEntityMove(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SceneEntityMoveCsReq, allocator);
    for (req.entity_motion_list.items) |entity_motion| {
        if (entity_motion.motion) |motion| {
            if (entity_motion.entity_id > 99999 and entity_motion.entity_id < 1000000 or entity_motion.entity_id == 0)
                log.debug("[POSITION] entity_id: {}, motion: {}", .{ entity_motion.entity_id, motion });
        }
    }
    try session.send(CmdID.CmdSceneEntityMoveScRsp, protocol.SceneEntityMoveScRsp{
        .retcode = 0,
        .entity_motion_list = req.entity_motion_list,
        .download_data = null,
    });
}

pub fn onEnterScene(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const entrance_config = &ConfigManager.global_game_config_cache.map_entrance_config;

    const req = try packet.getProto(protocol.EnterSceneCsReq, allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var floorID: u32 = 0;
    var planeID: u32 = 0;
    var teleportID: u32 = 0;
    for (entrance_config.map_entrance_config.items) |entrConf| {
        if (entrConf.id == req.entry_id) {
            floorID = entrConf.floor_id;
            planeID = entrConf.plane_id;
            teleportID = req.teleport_id;
        }
    }
    const scene_info = try scene_manager.createScene(planeID, floorID, req.entry_id, teleportID);
    std.debug.print("ENTER SCENE ENTRY ID: {}, PLANE ID: {}, FLOOR ID: {}, TELEPORT ID: {}\n", .{ req.entry_id, planeID, floorID, teleportID });
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .lineup = lineup,
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .scene = scene_info,
    });
    try session.send(CmdID.CmdEnterSceneScRsp, protocol.EnterSceneScRsp{
        .retcode = 0,
        .game_story_line_id = req.game_story_line_id,
        .is_close_map = req.is_close_map,
        .content_id = req.content_id,
        .is_over_map = true,
    });
}

pub fn onGetSceneMapInfo(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetSceneMapInfoCsReq, allocator);
    const cached_res_config = &ConfigManager.global_game_config_cache.res_config;
    const ranges = [_][2]usize{
        .{ 0, 101 },
        .{ 10000, 10051 },
        .{ 20000, 20001 },
        .{ 30000, 30020 },
    };
    const chest_list = &[_]protocol.ChestInfo{
        .{ .chest_type = protocol.ChestType.MAP_INFO_CHEST_TYPE_NORMAL },
        .{ .chest_type = protocol.ChestType.MAP_INFO_CHEST_TYPE_CHALLENGE },
        .{ .chest_type = protocol.ChestType.MAP_INFO_CHEST_TYPE_PUZZLE },
    };
    for (req.floor_id_list.items) |floor_id| {
        var rsp = protocol.GetSceneMapInfoScRsp.init(allocator);
        rsp.retcode = 0;
        rsp.content_id = req.content_id;
        rsp.entry_story_line_id = req.entry_story_line_id;
        rsp.IGFIKGHLLNO = true;
        var map_info = protocol.SceneMapInfo.init(allocator);
        try map_info.chest_list.appendSlice(chest_list);
        map_info.entry_id = @intCast(floor_id);
        map_info.floor_id = @intCast(floor_id);
        map_info.cur_map_entry_id = @intCast(floor_id);
        for (cached_res_config.scene_config.items) |sceneConf| {
            if (sceneConf.planeID != floor_id / 1000) continue;
            try map_info.unlock_teleport_list.ensureUnusedCapacity(sceneConf.teleports.items.len);
            try map_info.maze_prop_list.ensureUnusedCapacity(sceneConf.props.items.len);
            try map_info.maze_group_list.ensureUnusedCapacity(sceneConf.props.items.len);
            for (ranges) |range| {
                for (range[0]..range[1]) |i| {
                    try map_info.lighten_section_list.append(@intCast(i));
                }
            }
            for (sceneConf.teleports.items) |teleConf| {
                try map_info.unlock_teleport_list.append(@intCast(teleConf.teleportId));
            }
            for (sceneConf.props.items) |propConf| {
                try map_info.maze_prop_list.append(protocol.MazePropState{
                    .group_id = propConf.groupId,
                    .config_id = propConf.instId,
                    .state = propConf.propState,
                });
                try map_info.LMNGAHFNAON.append(protocol.OFCAIGDHPOH{
                    .group_id = propConf.groupId,
                    .config_id = propConf.instId,
                    .state = propConf.propState,
                });
                try map_info.maze_group_list.append(protocol.MazeGroup{
                    .NOBKEONAKLE = std.ArrayList(u32).init(allocator),
                    .group_id = propConf.groupId,
                });
            }
        }
        try rsp.scene_map_info.append(map_info);
        try session.send(protocol.CmdID.CmdGetSceneMapInfoScRsp, rsp);
    }
}
pub fn onGetUnlockTeleport(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetUnlockTeleportScRsp.init(allocator);
    const res_config = &ConfigManager.global_game_config_cache.res_config;
    for (res_config.scene_config.items) |sceneCof| {
        for (sceneCof.teleports.items) |tp| {
            try rsp.unlock_teleport_list.append(tp.teleportId);
        }
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetUnlockTeleportScRsp, rsp);
}
pub fn onEnterSection(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.EnterSectionCsReq, allocator);
    var rsp = protocol.EnterSectionScRsp.init(allocator);
    rsp.retcode = 0;
    std.debug.print("ENTER SECTION Id: {}\n", .{req.section_id});
    try session.send(CmdID.CmdEnterSectionScRsp, rsp);
}

pub fn onGetEnteredScene(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetEnteredSceneScRsp.init(allocator);
    var noti = protocol.EnteredSceneChangeScNotify.init(allocator);
    const entrance_config = &ConfigManager.global_game_config_cache.map_entrance_config;
    for (entrance_config.map_entrance_config.items) |entrance| {
        try rsp.entered_scene_info_list.append(protocol.EnteredSceneInfo{
            .floor_id = entrance.floor_id,
            .plane_id = entrance.plane_id,
        });
        try noti.entered_scene_info_list.append(protocol.EnteredSceneInfo{
            .floor_id = entrance.floor_id,
            .plane_id = entrance.plane_id,
        });
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdEnteredSceneChangeScNotify, noti);
    try session.send(CmdID.CmdGetEnteredSceneScRsp, rsp);
}

pub fn onSceneEntityTeleport(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SceneEntityTeleportCsReq, allocator);
    var rsp = protocol.SceneEntityTeleportScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.entity_motion = req.entity_motion;
    std.debug.print("SCENE ENTITY TP ENTRY ID: {}\n", .{req.entry_id});
    try session.send(CmdID.CmdSceneEntityTeleportScRsp, rsp);
}

pub fn onGetFirstTalkNpc(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFirstTalkNpcCsReq, allocator);
    var rsp = protocol.GetFirstTalkNpcScRsp.init(allocator);
    rsp.retcode = 0;
    for (req.npc_id_list.items) |id| {
        try rsp.npc_meet_status_list.append(protocol.FirstNpcTalkInfo{ .npc_id = id, .is_meet = true });
    }
    try session.send(CmdID.CmdGetFirstTalkNpcScRsp, rsp);
}

pub fn onGetFirstTalkByPerformanceNp(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFirstTalkByPerformanceNpcCsReq, allocator);
    var rsp = protocol.GetFirstTalkByPerformanceNpcScRsp.init(allocator);
    rsp.retcode = 0;
    for (req.performance_id_list.items) |id| {
        try rsp.npc_meet_status_list.append(
            protocol.NpcMeetByPerformanceStatus{ .performance_id = id, .is_meet = true },
        );
    }
    try session.send(CmdID.CmdGetFirstTalkByPerformanceNpcScRsp, rsp);
}

pub fn onGetNpcTakenReward(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetNpcTakenRewardCsReq, allocator);
    var rsp = protocol.GetNpcTakenRewardScRsp.init(allocator);
    const EventList = [_]u32{ 2136, 2134 };
    rsp.retcode = 0;
    rsp.npc_id = req.npc_id;
    try rsp.talk_event_list.appendSlice(&EventList);
    try session.send(CmdID.CmdGetNpcTakenRewardScRsp, rsp);
}
pub fn onUpdateGroupProperty(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UpdateGroupPropertyCsReq, allocator);
    var rsp = protocol.UpdateGroupPropertyScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.floor_id = req.floor_id;
    rsp.group_id = req.group_id;
    rsp.dimension_id = req.dimension_id;
    rsp.JAIBIEEKHEG = req.JAIBIEEKHEG;
    try session.send(CmdID.CmdUpdateGroupPropertyScRsp, rsp);
}
pub fn onChangePropTimeline(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ChangePropTimelineInfoCsReq, allocator);
    try session.send(CmdID.CmdChangePropTimelineInfoScRsp, protocol.ChangePropTimelineInfoScRsp{
        .retcode = 0,
        .prop_entity_id = req.prop_entity_id,
    });
}
pub fn onDeactivateFarmElement(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.DeactivateFarmElementCsReq, allocator);
    std.debug.print("DEACTIVATE FARM ELEMENT ENTITY ID: {}\n", .{req.entity_id});
    try session.send(CmdID.CmdDeactivateFarmElementScRsp, protocol.DeactivateFarmElementScRsp{
        .retcode = 0,
        .entity_id = req.entity_id,
    });
}
pub fn onActivateFarmElement(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ActivateFarmElementCsReq, allocator);
    std.debug.print("ACTIVATE FARM ELEMENT ENTITY ID: {}\n", .{req.entity_id});
    try session.send(CmdID.CmdActivateFarmElementScRsp, protocol.ActivateFarmElementScRsp{
        .retcode = 0,
        .world_level = req.world_level,
        .entity_id = req.entity_id,
    });
}
pub fn onSetGroupCustomSaveData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetGroupCustomSaveDataCsReq, allocator);
    //switch (req.AAMHHECOCOI) {
    //    .Owned => |val| {
    //        std.debug.print("CUSTOM SAVE DATA REQ: {s}\n", .{val.str});
    //    },
    //    .Const => |val| {
    //        std.debug.print("CUSTOM SAVE DATA REQ: {s}\n", .{val});
    //    },
    //    .Empty => {
    //        std.debug.print("CUSTOM SAVE DATA REQ: <empty string>\n", .{});
    //    },
    //}
    try session.send(CmdID.CmdSetGroupCustomSaveDataScRsp, protocol.SetGroupCustomSaveDataScRsp{
        .retcode = 0,
        .group_id = req.group_id,
        .entry_id = req.entry_id,
    });
}
pub fn onInteractProp(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.InteractPropCsReq, allocator);
    std.debug.print("INTERACT ID: {}\n", .{req.interact_id});
    try session.send(CmdID.CmdInteractPropScRsp, protocol.InteractPropScRsp{
        .retcode = 0,
        .prop_entity_id = req.prop_entity_id,
        .prop_state = 0,
    });
}
pub fn onChangeEraFlipperData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ChangeEraFlipperDataCsReq, allocator);
    try session.send(CmdID.CmdChangeEraFlipperDataScRsp, protocol.ChangeEraFlipperDataScRsp{
        .retcode = 0,
        .data = req.data,
    });
}
