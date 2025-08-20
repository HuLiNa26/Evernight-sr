const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("config.zig");
const Res_config = @import("res_config.zig");
const Data = @import("../data.zig");
const ChallegeStageManager = @import("../manager/battle_mgr.zig").ChallegeStageManager;
const scene_mgr_mod = @import("../manager/scene_mgr.zig");
const SceneManager = scene_mgr_mod.SceneManager;
const ChallengeSceneManager = scene_mgr_mod.ChallengeSceneManager;

const lineup_mgr_mod = @import("../manager/lineup_mgr.zig");
const LineupManager = lineup_mgr_mod.LineupManager;
const ChallengeLineupManager = lineup_mgr_mod.ChallengeLineupManager;
const deinitLineupInfo = lineup_mgr_mod.deinitLineupInfo;

const challenge_mgr_mod = @import("../manager/challenge_mgr.zig");
const ChallengeManager = challenge_mgr_mod.ChallengeManager;
const deinitCurChallenge = challenge_mgr_mod.deinitCurChallenge;
const Value = @import("../commands/value.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn UidGenerator() type {
    return struct {
        current_id: u32,

        const Self = @This();

        pub fn init() Self {
            return Self{ .current_id = 100000 };
        }

        pub fn nextId(self: *Self) u32 {
            self.current_id +%= 1; // Using wrapping addition
            return self.current_id;
        }
    };
}

fn contains(list: *const std.ArrayListAligned(u32, null), value: u32) bool {
    for (list.items) |item| {
        if (item == value) {
            return true;
        }
    }
    return false;
}
pub var on_challenge: bool = false;

pub const ChallengeBlessing = ArrayList(u32);
pub var challenge_blessing: []const u32 = &.{};
pub var challenge_mode: u32 = 0;

pub var challenge_planeID: u32 = 0;
pub var challenge_floorID: u32 = 0;
pub var challenge_entryID: u32 = 0;
pub var challenge_worldID: u32 = 0;
pub var challenge_monsterID: u32 = 0;
pub var challenge_eventID: u32 = 0;
pub var challenge_groupID: u32 = 0;
pub var challenge_maze_groupID: u32 = 0;
pub var challenge_stageID: u32 = 0;

pub var challengeID: u32 = 0;
pub var challenge_buffID: u32 = 0;

pub var challenge_peak_hard: bool = true;

pub const ChallengeAvatarList = ArrayList(u32);
pub var avatar_list: ChallengeAvatarList = ChallengeAvatarList.init(std.heap.page_allocator);

pub fn resetChallengeState() void {
    on_challenge = false;
    challenge_mode = 0;
    challenge_planeID = 0;
    challenge_floorID = 0;
    challenge_entryID = 0;
    challenge_worldID = 0;
    challenge_monsterID = 0;
    challenge_eventID = 0;
    challenge_groupID = 0;
    challenge_maze_groupID = 0;
    challenge_stageID = 0;
    challengeID = 0;
    challenge_buffID = 0;
    challenge_blessing = &.{};
    _ = avatar_list.clearRetainingCapacity();
}

pub const AvatarListMap = std.AutoHashMap(u32, std.ArrayList(u32));
pub var saved_peak_lineups: AvatarListMap = AvatarListMap.init(std.heap.page_allocator);

pub fn onGetChallenge(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var challenge_config = try Config.loadChallengeConfig(allocator, "resources/ChallengeMazeConfig.json");
    defer challenge_config.deinit();
    var rsp = protocol.GetChallengeScRsp.init(allocator);

    rsp.retcode = 0;

    for (challenge_config.challenge_config.items) |ids| {
        var challenge = protocol.Challenge.init(allocator);
        var history = protocol.ChallengeHistoryMaxLevel.init(allocator);
        challenge.challenge_id = ids.id;
        challenge.star = 7;
        history.level = 12;
        history.reward_display_type = 101212;
        challenge.taken_reward = 42;
        if (ids.id > 20000 and ids.id < 30000) {
            history.level = 4;
            history.reward_display_type = 101404;
            challenge.score_id = 40000;
            challenge.score_two = 40000;
        }
        if (ids.id > 30000) {
            history.level = 4;
            history.reward_display_type = 101404;
        }
        try rsp.max_level_list.append(history);
        try rsp.challenge_list.append(challenge);
    }

    try session.send(CmdID.CmdGetChallengeScRsp, rsp);
}
pub fn onGetChallengeGroupStatistics(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetChallengeGroupStatisticsCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetChallengeGroupStatisticsScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.group_id = req.group_id;
    try session.send(CmdID.CmdGetChallengeGroupStatisticsScRsp, rsp);
}
pub fn onLeaveChallenge(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20422, 20422001, 2042201, 1025);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    resetChallengeState();
    challenge_mode = 0;
    try session.send(CmdID.CmdLeaveChallengeScRsp, protocol.LeaveChallengeScRsp{
        .retcode = 0,
    });
}

pub fn onLeaveChallengePeak(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20422, 20422001, 2042201, 1025);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    resetChallengeState();
    challenge_mode = 0;
    try session.send(CmdID.CmdLeaveChallengePeakScRsp, protocol.LeaveChallengePeakScRsp{
        .retcode = 0,
    });
}

pub fn onGetCurChallengeScRsp(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetCurChallengeScRsp.init(allocator);
    var lineup_manager = ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(avatar_list);
    var challenge_manager = ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallenge(
        challengeID,
        challenge_buffID,
    );

    rsp.retcode = 0;
    if (on_challenge == true) {
        rsp.cur_challenge = cur_challenge_info;
        try rsp.lineup_list.append(lineup_info);

        std.debug.print("CURRENT CHALLENGE STAGE ID:{}\n", .{challenge_stageID});
        std.debug.print("CURRENT CHALLENGE LINEUP AVATAR ID:{}\n", .{avatar_list});
        std.debug.print("CURRENT CHALLENGE MONSTER ID:{}\n", .{challenge_monsterID});
        if (challenge_mode == 0) {
            std.debug.print("CURRENT CHALLENGE: {} MOC\n", .{challenge_mode});
        } else if (challenge_mode == 1) {
            std.debug.print("CURRENT CHALLENGE: {} PF\n", .{challenge_mode});
            std.debug.print("CURRENT CHALLENGE STAGE BLESSING ID:{}, SELECTED BLESSING ID:{}\n", .{ challenge_blessing[0], challenge_blessing[1] });
        } else {
            std.debug.print("CURRENT CHALLENGE: {} AS\n", .{challenge_mode});
            std.debug.print("CURRENT CHALLENGE STAGE BLESSING ID:{}, SELECTED BLESSING ID:{}\n", .{ challenge_blessing[0], challenge_blessing[1] });
        }
    } else {
        deinitLineupInfo(&lineup_info);
        deinitCurChallenge(&cur_challenge_info);
        std.debug.print("CURRENT ON CHALLENGE STATE: {}\n", .{on_challenge});
    }

    try session.send(CmdID.CmdGetCurChallengeScRsp, rsp);
}
pub fn onStartChallenge(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartChallengeCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.StartChallengeScRsp.init(allocator);
    if (Value.custom_mode == true) {
        challengeID = Value.selected_challenge_id;
        challenge_buffID = Value.selected_buff_id;
        if (Value.challenge_node == 0) {
            for (req.first_lineup.items) |id| {
                try avatar_list.append(id);
            }
        } else {
            {
                for (req.second_lineup.items) |id| {
                    try avatar_list.append(id);
                }
            }
        }
    } else {
        challengeID = req.challenge_id;
        if (Value.challenge_node == 0) {
            for (req.first_lineup.items) |id| {
                try avatar_list.append(id);
            }
            if (challengeID > 20000 and challengeID < 30000)
                challenge_buffID = req.stage_info.?.story_info.?.buff_one;
            if (challengeID > 30000)
                challenge_buffID = req.stage_info.?.boss_info.?.buff_one;
        } else {
            for (req.second_lineup.items) |id| {
                try avatar_list.append(id);
            }
            if (challengeID > 20000 and challengeID < 30000)
                challenge_buffID = req.stage_info.?.story_info.?.buff_two;
            if (challengeID > 30000)
                challenge_buffID = req.stage_info.?.boss_info.?.buff_two;
        }
    }
    var lineup_manager = ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(avatar_list);
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallenge(
        challengeID,
        challenge_buffID,
    );
    _ = &cur_challenge_info;

    var scene_challenge_manager = ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createScene(
        avatar_list,
        challenge_planeID,
        challenge_floorID,
        challenge_entryID,
        challenge_worldID,
        challenge_monsterID,
        challenge_eventID,
        challenge_groupID,
        challenge_maze_groupID,
    );
    _ = &scene_info;

    rsp.retcode = 0;
    rsp.scene = scene_info;
    rsp.cur_challenge = cur_challenge_info;
    try rsp.lineup_list.append(lineup_info);

    on_challenge = true;

    try session.send(CmdID.CmdStartChallengeScRsp, rsp);
    std.debug.print("SEND PLANE ID {} FLOOR ID {} ENTRY ID {} GROUP ID {} MAZE GROUP ID {}\n", .{
        challenge_planeID,
        challenge_floorID,
        challenge_entryID,
        challenge_groupID,
        challenge_maze_groupID,
    });
    const anchor_motion = ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
    if (anchor_motion) |motion| {
        for (scene_info.entity_group_list.items) |*group| {
            for (group.entity_list.items) |*entity| {
                if (entity.actor != null) {
                    try session.send(
                        CmdID.CmdSceneEntityMoveScNotify,
                        protocol.SceneEntityMoveScNotify{
                            .entity_id = entity.entity_id,
                            .entry_id = scene_info.entry_id,
                            .motion = motion,
                        },
                    );
                }
            }
        }
    }
}
pub fn onTakeChallengeReward(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TakeChallengeRewardCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.TakeChallengeRewardScRsp.init(allocator);
    var reward = protocol.TakenChallengeRewardInfo.init(allocator);
    if (req.group_id > 2000) reward.star_count = 12 else reward.star_count = 36;
    try rsp.taken_reward_list.append(reward);
    rsp.retcode = 0;
    rsp.group_id = req.group_id;
    try session.send(CmdID.CmdTakeChallengeRewardScRsp, rsp);
}

// Peak challenge WIP
pub fn onGetCurChallengePeak(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetCurChallengePeakScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetCurChallengePeakScRsp, rsp);
}
pub fn onGetChallengePeakData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChallengePeakDataScRsp.init(allocator);
    rsp.retcode = 0;
    const target_king = [_]u32{ 3003, 3004, 3005 };
    const cleared_avatar = [_]u32{1413};
    var reward = ArrayList(u32).init(allocator);
    for (1..13) |i| {
        try reward.append(@intCast(i));
    }
    var ava = ArrayList(u32).init(allocator);
    try ava.appendSlice(&cleared_avatar);
    const peak_group = try Config.loadChallengePeakGroupConfig(allocator, "resources/ChallengePeakGroupConfig.json");
    const peak_boss = try Config.loadChallengePeakBossConfig(allocator, "resources/ChallengePeakBossConfig.json");
    for (peak_group.challenge_peak_group.items) |id| {
        for (peak_boss.challenge_peak_boss_config.items) |boss| {
            if (boss.id == id.boss_level_id) {
                var data = protocol.ChallengePeakData.init(allocator);
                data.knight_stage_clear = 3;
                data.knight_stage_star = 9;
                data.challenge_peak_group_id = id.id;
                data.challenge_peak_reward_taken = reward;
                data.challenge_peak_data_info = .{
                    .buff_id = boss.buff_list.items[0],
                    .challenge_peak_id = id.boss_level_id,
                    .peak_avatar_list = ava,
                    .challenge_peak_clear = true,
                    .challenge_peak_record = .{
                        .buff_id = boss.buff_list.items[0],
                        .peak_avatar_list_display = ava,
                        .peak_avatar_list = ava,
                    },
                    .challenge_peak_record_display = .{
                        .peak_avatar_list_display = ava,
                        .peak_avatar_list = ava,
                        .challenge_peak_perfect_clear = true,
                    },
                    .peak_target = blk: {
                        var list = std.ArrayList(u32).init(allocator);
                        try list.appendSlice(&target_king);
                        break :blk list;
                    },
                };
                try rsp.challenge_peak_data.append(data);
                rsp.cur_challenge_peak_group_id = id.id;
            }
        }
    }
    try session.send(CmdID.CmdGetChallengePeakDataScRsp, rsp);
}
pub fn onReStartChallengePeak(session: *Session, _: *const Packet, _: Allocator) !void {
    try session.send(CmdID.CmdReStartChallengePeakScRsp, protocol.ReStartChallengePeakScRsp{
        .retcode = 0,
    });
}
pub fn onSetChallengePeakMobLineupAvatar(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetChallengePeakMobLineupAvatarCsReq, allocator);
    defer req.deinit();
    var update = protocol.ChallengePeakData.init(allocator);
    update.challenge_peak_group_id = req.challenge_peak_group_id;
    update.knight_stage_clear = 3;
    update.knight_stage_star = 9;
    for (req.lineup_list.items) |list| {
        var build = protocol.ChallengePeakClearedData.init(allocator);
        build.challenge_peak_id = list.challenge_peak_id;
        build.peak_avatar_list = list.peak_avatar_list;
        var avatar_copy = std.ArrayList(u32).init(std.heap.page_allocator);
        try avatar_copy.appendSlice(list.peak_avatar_list.items);
        try saved_peak_lineups.put(list.challenge_peak_id, avatar_copy);
        try update.challenge_peak_cleared_data.append(build);
    }
    var rsp = protocol.SetChallengePeakMobLineupAvatarScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdChallengePeakGroupDataUpdateScNotify, protocol.ChallengePeakGroupDataUpdateScNotify{
        .update_data = update,
    });
    try session.send(CmdID.CmdSetChallengePeakMobLineupAvatarScRsp, rsp);
}
pub fn onStartChallengePeak(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartChallengePeakCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.StartChallengePeakScRsp.init(allocator);
    rsp.retcode = 0;
    if (req.peak_avatar_list.items.len != 0) {
        try avatar_list.appendSlice(req.peak_avatar_list.items);
    } else {
        if (saved_peak_lineups.get(req.challenge_peak_id)) |saved_list|
            try avatar_list.appendSlice(saved_list.items);
    }
    var lineup_manager = ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createPeakLineup(avatar_list);
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallengePeak(req.challenge_peak_id, req.peak_buff_id);
    _ = &cur_challenge_info;

    var scene_challenge_manager = ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createPeakScene(
        avatar_list,
        challenge_planeID,
        challenge_floorID,
        challenge_entryID,
        challenge_monsterID,
        challenge_eventID,
        challenge_groupID,
        challenge_maze_groupID,
    );
    _ = &scene_info;
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup_info,
        .scene = scene_info,
    });
    on_challenge = true;
    std.debug.print("SEND PLANE ID {} FLOOR ID {} ENTRY ID {} GROUP ID {} MAZE GROUP ID {}\n", .{
        challenge_planeID,
        challenge_floorID,
        challenge_entryID,
        challenge_groupID,
        challenge_maze_groupID,
    });
    const anchor_motion = ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
    if (anchor_motion) |motion| {
        for (scene_info.entity_group_list.items) |*group| {
            for (group.entity_list.items) |*entity| {
                if (entity.actor != null) {
                    try session.send(
                        CmdID.CmdSceneEntityMoveScNotify,
                        protocol.SceneEntityMoveScNotify{
                            .entity_id = entity.entity_id,
                            .entry_id = scene_info.entry_id,
                            .motion = motion,
                        },
                    );
                }
            }
        }
    }
    try session.send(CmdID.CmdStartChallengePeakScRsp, rsp);
}
pub fn onSetChallengePeakBossHardMode(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetChallengePeakBossHardModeCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.SetChallengePeakBossHardModeScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.peak_hard_mode = req.peak_hard_mode;
    rsp.challenge_peak_group_id = req.challenge_peak_group_id;
    challenge_peak_hard = req.peak_hard_mode;
    try session.send(CmdID.CmdSetChallengePeakBossHardModeScRsp, rsp);
}
pub fn onGetFriendBattleRecordDetail(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFriendBattleRecordDetailCsReq, allocator);
    var rsp = protocol.GetFriendBattleRecordDetailScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.uid = req.uid;
    const peak_group = try Config.loadChallengePeakGroupConfig(allocator, "resources/ChallengePeakGroupConfig.json");
    const peak_boss = try Config.loadChallengePeakBossConfig(allocator, "resources/ChallengePeakBossConfig.json");
    var record_list = ArrayList(protocol.ChallengeAvatarInfo).init(allocator);
    try record_list.appendSlice(&[_]protocol.ChallengeAvatarInfo{
        .{ .level = 80, .index = 0, .id = 1413, .avatar_type = protocol.AvatarType.AVATAR_UPGRADE_AVAILABLE_TYPE },
    });
    for (peak_group.challenge_peak_group.items) |group| {
        for (peak_boss.challenge_peak_boss_config.items) |boss| {
            if (boss.id == group.boss_level_id) {
                var peak_record = protocol.MNFMHOOAMNL.init(allocator);
                peak_record.group_id = group.id;
                peak_record.FAIDFGBDOJJ = .{
                    .buff_id = boss.buff_list.items[0],
                    .challenge_peak_id = group.boss_level_id,
                    .NHGOMAKHCOP = true,
                    .LGJCEPNMCKM = true,
                    .IEPHDLMLOAO = std.ArrayList(u32).init(allocator),
                    .lineup = .{
                        .avatar_list = record_list,
                    },
                };
                try rsp.FGCJFJJENJF.append(peak_record);
            }
        }
    }
    try session.send(CmdID.CmdGetFriendBattleRecordDetailScRsp, rsp);
}
