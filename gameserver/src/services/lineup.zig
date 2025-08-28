const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");

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

    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();

    for (req.lineup_slot_list.items) |ok| {
        try ids.append(ok.id);
    }
    const lineup = try LineupManager.buildLineup(allocator, ids.items, null);
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
