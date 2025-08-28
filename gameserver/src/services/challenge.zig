const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const ChallengeManager = @import("../manager/challenge_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Logic = @import("../utils/logic.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetChallenge(session: *Session, _: *const Packet, allocator: Allocator) !void {
    const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;
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
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20422, 20422001, 2042201, 1025);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    Logic.Challenge().resetChallengeState();
    try session.send(CmdID.CmdLeaveChallengeScRsp, protocol.LeaveChallengeScRsp{
        .retcode = 0,
    });
}

pub fn onLeaveChallengePeak(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    _ = &lineup;
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var scene_info = try scene_manager.createScene(20422, 20422001, 2042201, 1025);
    _ = &scene_info;
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
    Logic.Challenge().resetChallengeState();
    try session.send(CmdID.CmdLeaveChallengePeakScRsp, protocol.LeaveChallengePeakScRsp{
        .retcode = 0,
    });
}

pub fn onGetCurChallengeScRsp(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetCurChallengeScRsp.init(allocator);
    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(Logic.Challenge().GetAvatarIDs());
    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallenge(
        Logic.Challenge().GetChallengeID(),
        Logic.Challenge().GetChallengeBuffID(),
    );

    rsp.retcode = 0;
    if (Logic.Challenge().ChallengeMode()) {
        rsp.cur_challenge = cur_challenge_info;
        try rsp.lineup_list.append(lineup_info);
        Logic.Challenge().GetCurChallengeStatus();
    } else {
        LineupManager.deinitLineupInfo(&lineup_info);
        ChallengeManager.deinitCurChallenge(&cur_challenge_info);
        std.debug.print("NOT ON CHALLENGE\n", .{});
    }

    try session.send(CmdID.CmdGetCurChallengeScRsp, rsp);
}
pub fn onStartChallenge(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartChallengeCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.StartChallengeScRsp.init(allocator);
    if (Logic.CustomMode().CustomMode()) {
        Logic.Challenge().SetChallengeID(Logic.CustomMode().GetCustomChallengeID());
        Logic.Challenge().SetChallengeBuffID(Logic.CustomMode().GetCustomBuffID());
        if (Logic.CustomMode().FirstNode()) {
            try Logic.Challenge().AddAvatar(req.first_lineup.items);
        } else {
            try Logic.Challenge().AddAvatar(req.second_lineup.items);
        }
    } else {
        Logic.Challenge().SetChallengeID(req.challenge_id);
        if (Logic.CustomMode().FirstNode()) {
            try Logic.Challenge().AddAvatar(req.first_lineup.items);
            if (Logic.Challenge().GameModePF())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.story_info.?.buff_one);
            if (Logic.Challenge().GameModeAS())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.boss_info.?.buff_one);
        } else {
            try Logic.Challenge().AddAvatar(req.second_lineup.items);
            if (Logic.Challenge().GameModePF())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.story_info.?.buff_two);
            if (Logic.Challenge().GameModeAS())
                Logic.Challenge().SetChallengeBuffID(req.stage_info.?.boss_info.?.buff_two);
        }
    }
    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createLineup(Logic.Challenge().GetAvatarIDs());
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallenge(
        Logic.Challenge().GetChallengeID(),
        Logic.Challenge().GetChallengeBuffID(),
    );
    _ = &cur_challenge_info;

    const ids = Logic.Challenge().GetSceneIDs();
    var scene_challenge_manager = SceneManager.ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createScene(
        Logic.Challenge().GetAvatarIDs(),
        ids[0],
        ids[1],
        ids[2],
        ids[3],
        ids[4],
        ids[5],
        ids[6],
        ids[7],
    );
    _ = &scene_info;

    rsp.retcode = 0;
    rsp.scene = scene_info;
    rsp.cur_challenge = cur_challenge_info;
    try rsp.lineup_list.append(lineup_info);

    Logic.Challenge().SetChallenge();
    try session.send(CmdID.CmdStartChallengeScRsp, rsp);
    Logic.Challenge().GetCurSceneStatus();
    const anchor_motion = SceneManager.ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
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
    var reward = ArrayList(u32).init(allocator);
    for (1..13) |i| {
        try reward.append(@intCast(i));
    }
    var ava = ArrayList(u32).init(allocator);
    try ava.appendSlice(&[_]u32{1413});
    const peak_group = &ConfigManager.global_game_config_cache.challenge_peak_group_config;
    const peak_boss = &ConfigManager.global_game_config_cache.challenge_peak_boss_config;
    for (peak_group.challenge_peak_group.items) |id| {
        for (peak_boss.challenge_peak_boss_config.items) |boss| {
            if (boss.id == id.boss_level_id) {
                var data = protocol.ChallengePeakData.init(allocator);
                const unk = ArrayList(protocol.JNLLONBKNEI).init(allocator);
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
                        .NBAMNJCGOIK = unk,
                        .buff_id = boss.buff_list.items[0],
                        .peak_avatar_list_display = ava,
                        .peak_avatar_list = ava,
                    },
                    .challenge_peak_record_display = .{
                        .NBAMNJCGOIK = unk,
                        .buff_id = boss.buff_list.items[0],
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
        try Logic.Challenge().SavePeakLineup(list.challenge_peak_id, list.peak_avatar_list.items);
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
        Logic.Challenge().SetPeakBoss(true);
        try Logic.Challenge().AddAvatar(req.peak_avatar_list.items);
    } else {
        Logic.Challenge().SetPeakBoss(false);
        try Logic.Challenge().LoadPeakLineup(req.challenge_peak_id);
    }
    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    var lineup_info = try lineup_manager.createPeakLineup(Logic.Challenge().GetAvatarIDs());
    _ = &lineup_info;

    var challenge_manager = ChallengeManager.ChallengeManager.init(allocator);
    var cur_challenge_info = try challenge_manager.createChallengePeak(req.challenge_peak_id, req.peak_buff_id);
    _ = &cur_challenge_info;

    const ids = Logic.Challenge().GetPeakSceneIDs();
    var scene_challenge_manager = SceneManager.ChallengeSceneManager.init(allocator);
    var scene_info = try scene_challenge_manager.createPeakScene(
        Logic.Challenge().GetAvatarIDs(),
        ids[0],
        ids[1],
        ids[2],
        ids[3],
        ids[4],
        ids[5],
        ids[6],
    );
    _ = &scene_info;
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup_info,
        .scene = scene_info,
    });
    Logic.Challenge().SetChallenge();
    Logic.Challenge().GetCurSceneStatus();
    const anchor_motion = SceneManager.ChallengeSceneManager.getAnchorMotion(scene_info.entry_id);
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
    Logic.Challenge().SetChallengePeakHard(req.peak_hard_mode);
    try session.send(CmdID.CmdSetChallengePeakBossHardModeScRsp, rsp);
}
pub fn onGetFriendBattleRecordDetail(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFriendBattleRecordDetailCsReq, allocator);
    var rsp = protocol.GetFriendBattleRecordDetailScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.uid = req.uid;
    const peak_group = &ConfigManager.global_game_config_cache.challenge_peak_group_config;
    const peak_boss = &ConfigManager.global_game_config_cache.challenge_peak_boss_config;
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
