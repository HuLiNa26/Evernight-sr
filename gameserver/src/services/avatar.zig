const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const Uid = @import("../utils/uid.zig");

const AvatarManager = @import("../manager/avatar_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetAvatarData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const config = &ConfigManager.global_game_config_cache.game_config;
    Uid.resetGlobalUidGen(0);
    const req = try packet.getProto(protocol.GetAvatarDataCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetAvatarDataScRsp.init(allocator);
    rsp.is_get_all = req.is_get_all;
    for (Data.AllAvatars) |id| {
        const avatar = try AvatarManager.createAllAvatar(allocator, id);
        try rsp.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try AvatarManager.createAvatar(allocator, avatarConf);
        try rsp.avatar_list.append(avatar);
    }
    const multis = try AvatarManager.createAllMultiPath(allocator, config);
    try rsp.multi_path_avatar_info_list.appendSlice(multis.items);
    try rsp.basic_type_id_list.appendSlice(&Data.MultiAvatar);
    try rsp.cur_avatar_path.append(.{ .key = 1001, .value = switch (AvatarManager.m7th) {
        1224 => .Mar_7thRogueType,
        else => .Mar_7thKnightType,
    } });
    try rsp.cur_avatar_path.append(.{ .key = 8001, .value = switch (AvatarManager.mc_id) {
        8002 => .GirlWarriorType,
        8004 => .GirlKnightType,
        8006 => .GirlShamanType,
        8008 => .GirlMemoryType,
        else => .GirlMemoryType,
    } });
    try session.send(CmdID.CmdGetAvatarDataScRsp, rsp);
}

pub fn onGetBasicInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetBasicInfoScRsp.init(allocator);
    rsp.gender = 2;
    rsp.is_gender_set = true;
    rsp.player_setting_info = .{};
    try session.send(CmdID.CmdGetBasicInfoScRsp, rsp);
}

pub fn onSetAvatarPath(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.SetAvatarPathScRsp.init(allocator);

    const req = try packet.getProto(protocol.SetAvatarPathCsReq, allocator);
    defer req.deinit();
    rsp.avatar_id = req.avatar_id;
    if (rsp.avatar_id == protocol.MultiPathAvatarType.Mar_7thKnightType) {
        AvatarManager.m7th = 1001;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.Mar_7thRogueType) {
        AvatarManager.m7th = 1224;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlWarriorType) {
        AvatarManager.mc_id = 8002;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlKnightType) {
        AvatarManager.mc_id = 8004;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlShamanType) {
        AvatarManager.mc_id = 8006;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlMemoryType) {
        AvatarManager.mc_id = 8008;
    }

    var change = protocol.AvatarPathChangedNotify.init(allocator);

    if (req.avatar_id == protocol.MultiPathAvatarType.GirlMemoryType) {
        change.base_avatar_id = 8008;
    } else if (req.avatar_id == protocol.MultiPathAvatarType.GirlShamanType) {
        change.base_avatar_id = 8006;
    } else if (req.avatar_id == protocol.MultiPathAvatarType.GirlKnightType) {
        change.base_avatar_id = 8004;
    } else if (req.avatar_id == protocol.MultiPathAvatarType.GirlWarriorType) {
        change.base_avatar_id = 8002;
    }
    change.cur_multi_path_avatar_type = req.avatar_id;

    var sync = protocol.PlayerSyncScNotify.init(allocator);

    const config = &ConfigManager.global_game_config_cache.game_config;
    Uid.resetGlobalUidGens();
    var char = protocol.AvatarSync.init(allocator);
    for (Data.AllAvatars) |id| {
        const avatar = try AvatarManager.createAllAvatar(allocator, id);
        try char.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try AvatarManager.createAvatar(allocator, avatarConf);
        try char.avatar_list.append(avatar);
    }
    const multis = try AvatarManager.createAllMultiPath(allocator, config);

    var lineup = protocol.SyncLineupNotify.init(allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const refresh = try lineup_mgr.createLineup();

    lineup.lineup = refresh;
    sync.avatar_sync = char;
    try sync.multi_path_avatar_info_list.appendSlice(multis.items);

    try session.send(CmdID.CmdAvatarPathChangedNotify, change);
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
    try session.send(CmdID.CmdSyncLineupNotify, lineup);
    try session.send(CmdID.CmdSetAvatarPathScRsp, rsp);
}
pub fn onDressAvatarSkin(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.DressAvatarSkinScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdDressAvatarSkinScRsp, rsp);
}
pub fn onTakeOffAvatarSkin(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.TakeOffAvatarSkinScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdTakeOffAvatarSkinScRsp, rsp);
}
pub fn onGetBigDataAll(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetBigDataAllRecommendCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetBigDataAllRecommendScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.big_data_recommend_type = req.big_data_recommend_type;
    try session.send(CmdID.CmdGetBigDataAllRecommendScRsp, rsp);
}
pub fn onGetBigData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetBigDataRecommendCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetBigDataRecommendScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.big_data_recommend_type = req.big_data_recommend_type;
    rsp.equip_avatar = req.equip_avatar;
    try session.send(CmdID.CmdGetBigDataRecommendScRsp, rsp);
}
pub fn onGetPreAvatarGrowthInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPreAvatarGrowthInfoScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetPreAvatarGrowthInfoScRsp, rsp);
}
