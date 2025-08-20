const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("../services/config.zig");
const Data = @import("../data.zig");
const ChallengeData = @import("../services/challenge.zig");
const NodeCheck = @import("../commands/value.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

fn contains(list: *const std.ArrayListAligned(u32, null), value: u32) bool {
    for (list.items) |item| {
        if (item == value) {
            return true;
        }
    }
    return false;
}

pub const ChallengeManager = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) ChallengeManager {
        return ChallengeManager{ .allocator = allocator };
    }
    pub fn createChallenge(
        self: *ChallengeManager,
        challenge_id: u32,
        buff_id: u32,
    ) !protocol.CurChallenge {
        const challenge_config = try Config.loadChallengeConfig(self.allocator, "resources/ChallengeMazeConfig.json");
        const entrance_config = try Config.loadMapEntranceConfig(self.allocator, "resources/MapEntrance.json");
        const maze_config = try Config.loadMazePlaneConfig(self.allocator, "resources/MazePlane.json");

        var challenge_blessing_list = ChallengeData.ChallengeBlessing{
            .allocator = std.heap.page_allocator,
            .items = &.{},
            .capacity = 0,
        };

        var cur_challenge_info = protocol.CurChallenge.init(self.allocator);
        cur_challenge_info.challenge_id = challenge_id;
        cur_challenge_info.score_id = if (challenge_id > 20000 and challenge_id < 30000) 40000 else 0;
        cur_challenge_info.score_two = 0;
        cur_challenge_info.status = protocol.ChallengeStatus.CHALLENGE_DOING;
        cur_challenge_info.extra_lineup_type = if (NodeCheck.challenge_node == 0) protocol.ExtraLineupType.LINEUP_CHALLENGE else protocol.ExtraLineupType.LINEUP_CHALLENGE_2;
        if (NodeCheck.challenge_node == 0) {
            for (challenge_config.challenge_config.items) |challengeConf| {
                if (challengeConf.id == challenge_id) {
                    std.debug.print("TRACING CONFIG ID {} WITH CHALLENGE ID {}\n", .{ challengeConf.id, challenge_id });
                    for (entrance_config.map_entrance_config.items) |entrance| {
                        if (entrance.id == challengeConf.map_entrance_id) {
                            for (maze_config.maze_plane_config.items) |maze| {
                                if (contains(&maze.floor_id_list, entrance.floor_id)) {
                                    if (challenge_id > 20000 and challenge_id < 30000) {
                                        var story_buff = protocol.ChallengeStoryBuffList{
                                            .buff_list = ArrayList(u32).init(self.allocator),
                                        };
                                        try story_buff.buff_list.append(challengeConf.maze_buff_id);
                                        try story_buff.buff_list.append(buff_id);
                                        try challenge_blessing_list.appendSlice(story_buff.buff_list.items);
                                        cur_challenge_info.stage_info = .{
                                            .cur_story_buffs = story_buff,
                                        };
                                        ChallengeData.challenge_mode = 1;
                                    } else if (challenge_id > 30000) {
                                        var boss_buff = protocol.ChallengeBossBuffList{
                                            .buff_list = ArrayList(u32).init(self.allocator),
                                            .challenge_boss_const = 1,
                                        };
                                        try boss_buff.buff_list.append(challengeConf.maze_buff_id);
                                        try boss_buff.buff_list.append(buff_id);
                                        try challenge_blessing_list.appendSlice(boss_buff.buff_list.items);
                                        cur_challenge_info.stage_info = .{
                                            .cur_boss_buffs = boss_buff,
                                        };
                                        ChallengeData.challenge_mode = 2;
                                    }
                                    ChallengeData.challenge_floorID = entrance.floor_id;
                                    ChallengeData.challenge_worldID = maze.world_id;
                                    ChallengeData.challenge_monsterID = challengeConf.npc_monster_id_list1.items[challengeConf.npc_monster_id_list1.items.len - 1];
                                    ChallengeData.challenge_eventID = challengeConf.event_id_list1.items[challengeConf.event_id_list1.items.len - 1];
                                    ChallengeData.challenge_groupID = challengeConf.maze_group_id1;
                                    ChallengeData.challenge_maze_groupID = challengeConf.maze_group_id1;
                                    ChallengeData.challenge_planeID = maze.challenge_plane_id;
                                    ChallengeData.challenge_entryID = challengeConf.map_entrance_id;
                                }
                            }
                        }
                    }
                }
            }
        } else {
            for (challenge_config.challenge_config.items) |challengeConf| {
                if (challengeConf.id == challenge_id) {
                    std.debug.print("TRACING CONFIG ID {} WITH CHALLENGE ID {}\n", .{ challengeConf.id, challenge_id });
                    for (entrance_config.map_entrance_config.items) |entrance| {
                        if (entrance.id == challengeConf.map_entrance_id2) {
                            for (maze_config.maze_plane_config.items) |maze| {
                                if (contains(&maze.floor_id_list, entrance.floor_id)) {
                                    if (challengeConf.maze_group_id2) |id| {
                                        if (challenge_id > 20000 and challenge_id < 30000) {
                                            var story_buff = protocol.ChallengeStoryBuffList{
                                                .buff_list = ArrayList(u32).init(self.allocator),
                                            };
                                            try story_buff.buff_list.append(challengeConf.maze_buff_id);
                                            try story_buff.buff_list.append(buff_id);
                                            try challenge_blessing_list.appendSlice(story_buff.buff_list.items);
                                            cur_challenge_info.stage_info = .{
                                                .cur_story_buffs = story_buff,
                                            };
                                            ChallengeData.challenge_mode = 1;
                                        } else if (challenge_id > 30000) {
                                            var boss_buff = protocol.ChallengeBossBuffList{
                                                .buff_list = ArrayList(u32).init(self.allocator),
                                                .challenge_boss_const = 1,
                                            };
                                            try boss_buff.buff_list.append(challengeConf.maze_buff_id);
                                            try boss_buff.buff_list.append(buff_id);
                                            try challenge_blessing_list.appendSlice(boss_buff.buff_list.items);
                                            cur_challenge_info.stage_info = .{
                                                .cur_boss_buffs = boss_buff,
                                            };
                                            ChallengeData.challenge_mode = 2;
                                        }
                                        ChallengeData.challenge_floorID = entrance.floor_id;
                                        ChallengeData.challenge_worldID = maze.world_id;
                                        ChallengeData.challenge_monsterID = challengeConf.npc_monster_id_list2.items[challengeConf.npc_monster_id_list2.items.len - 1];
                                        ChallengeData.challenge_eventID = challengeConf.event_id_list2.items[challengeConf.event_id_list2.items.len - 1];
                                        ChallengeData.challenge_groupID = id;
                                        ChallengeData.challenge_maze_groupID = id;
                                        ChallengeData.challenge_planeID = maze.challenge_plane_id;
                                        ChallengeData.challenge_entryID = challengeConf.map_entrance_id2;
                                    } else {
                                        std.debug.print("THIS CHALLENGE ID: {} DOES NOT SUPPORT 2ND NODE. PLEASE DO COMMAND /node TO SWITCH BACK TO FIRST NODE\n", .{challenge_id});
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        ChallengeData.challenge_blessing = challenge_blessing_list.items[0..challenge_blessing_list.items.len];
        ChallengeData.challenge_stageID = ChallengeData.challenge_eventID;
        return cur_challenge_info;
    }
    pub fn createChallengePeak(
        self: *ChallengeManager,
        challenge_peak_id: u32,
        buff_id: u32,
    ) !void {
        var challenge_blessing_list = ChallengeData.ChallengeBlessing{
            .allocator = std.heap.page_allocator,
            .items = &.{},
            .capacity = 0,
        };
        const entrance_config = try Config.loadMapEntranceConfig(self.allocator, "resources/MapEntrance.json");
        const peak_config = try Config.loadChallengePeakConfig(self.allocator, "resources/ChallengePeakConfig.json");
        const peak_boss_config = try Config.loadChallengePeakBossConfig(self.allocator, "resources/ChallengePeakBossConfig.json");

        for (peak_config.challenge_peak.items) |peak| {
            if (peak.id == challenge_peak_id) {
                for (entrance_config.map_entrance_config.items) |entrance| {
                    if (entrance.id == peak.map_entrance_id) {
                        ChallengeData.challenge_entryID = peak.map_entrance_id;
                        ChallengeData.challenge_planeID = entrance.plane_id;
                        ChallengeData.challenge_floorID = entrance.floor_id;
                        ChallengeData.challenge_monsterID = peak.npc_monster_id_list.items[peak.npc_monster_id_list.items.len - 1];
                        if (challenge_peak_id % 10 == 4 and ChallengeData.challenge_peak_hard == true) {
                            ChallengeData.challenge_eventID = peak.event_id_list.items[peak.event_id_list.items.len - 1] + 1;
                        } else {
                            ChallengeData.challenge_eventID = peak.event_id_list.items[peak.event_id_list.items.len - 1];
                        }
                        ChallengeData.challenge_maze_groupID = peak.maze_group_id;
                        ChallengeData.challenge_groupID = peak.maze_group_id;
                        if (buff_id != 0) try challenge_blessing_list.append(buff_id);
                        if (ChallengeData.challenge_peak_hard) {
                            for (peak_boss_config.challenge_peak_boss_config.items) |boss| {
                                if (boss.id == challenge_peak_id) try challenge_blessing_list.appendSlice(boss.hard_tag_list.items);
                            }
                        } else {
                            try challenge_blessing_list.appendSlice(peak.tag_list.items);
                        }
                    }
                }
            }
        }
        ChallengeData.challenge_blessing = challenge_blessing_list.items[0..challenge_blessing_list.items.len];
        ChallengeData.challenge_stageID = ChallengeData.challenge_eventID;
    }
};

pub fn deinitCurChallenge(challenge: *protocol.CurChallenge) void {
    if (challenge.stage_info) |*stage_info| {
        if (stage_info.cur_story_buffs) |*story_buffs| {
            story_buffs.buff_list.deinit();
        }
        if (stage_info.cur_boss_buffs) |*boss_buffs| {
            boss_buffs.buff_list.deinit();
        }
    }
}
