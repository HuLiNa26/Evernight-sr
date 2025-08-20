const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("config.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const BattleManager = @import("../manager/battle_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub var leader_slot: u32 = 0;

pub fn onGetCurLineupData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdGetCurLineupDataScRsp, protocol.GetCurLineupDataScRsp{
        .retcode = 0,
        .lineup = lineup,
    });
}

pub fn onChangeLineupLeader(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ChangeLineupLeaderCsReq, allocator);
    leader_slot = req.slot;
    try session.send(CmdID.CmdChangeLineupLeaderScRsp, protocol.ChangeLineupLeaderScRsp{
        .slot = req.slot,
        .retcode = 0,
    });
}

pub fn onReplaceLineup(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ReplaceLineupCsReq, allocator);
    var lineup = protocol.LineupInfo.init(allocator);
    lineup.mp = 5;
    lineup.max_mp = 5;
    lineup.name = .{ .Const = "EvernightSR" };
    for (req.lineup_slot_list.items) |ok| {
        const avatar = protocol.LineupAvatar{
            .id = ok.id,
            .slot = ok.slot,
            .satiety = 0,
            .hp = 10000,
            .avatar_type = protocol.AvatarType.AVATAR_FORMAL_TYPE,
            .sp_bar = .{ .cur_sp = 10000, .max_sp = 10000 },
        };
        if (ok.id == 1408) {
            lineup.mp = 7;
            lineup.max_mp = 7;
        }
        try lineup.avatar_list.append(avatar);
    }

    var id_list = try allocator.alloc(u32, req.lineup_slot_list.items.len);
    defer allocator.free(id_list);
    for (req.lineup_slot_list.items, 0..) |slot, idx| {
        if (idx >= 4) {
            break;
        }
        id_list[idx] = slot.id;
    }
    try LineupManager.getSelectedAvatarID(allocator, id_list);

    var rsp = protocol.SyncLineupNotify.init(allocator);
    rsp.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, rsp);
    try session.send(CmdID.CmdReplaceLineupScRsp, protocol.ReplaceLineupScRsp{
        .retcode = 0,
    });
}
pub fn onSetLineupName(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetLineupNameCsReq, allocator);
    try session.send(CmdID.CmdSetLineupNameScRsp, protocol.SetLineupNameScRsp{
        .index = req.index,
        .name = req.name,
        .retcode = 0,
    });
}
