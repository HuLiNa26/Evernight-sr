const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const Sync = @import("../commands/sync.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetBag(session: *Session, _: *const Packet, allocator: Allocator) !void {
    const config = &ConfigManager.global_game_config_cache.game_config;
    var rsp = protocol.GetBagScRsp.init(allocator);
    rsp.equipment_list = ArrayList(protocol.Equipment).init(allocator);
    rsp.relic_list = ArrayList(protocol.Relic).init(allocator);
    for (Data.ItemList) |tid| {
        try rsp.material_list.append(.{ .tid = tid, .num = 100 });
    }
    for (config.avatar_config.items) |avatarConf| {
        const lc = try AvatarManager.createEquipment(avatarConf.lightcone, avatarConf.id);
        try rsp.equipment_list.append(lc);
        for (avatarConf.relics.items) |input| {
            const r = try AvatarManager.createRelic(allocator, input, avatarConf.id);
            try rsp.relic_list.append(r);
        }
    }
    try session.send(CmdID.CmdGetBagScRsp, rsp);
}
pub fn onUseItem(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UseItemCsReq, allocator);
    var rsp = protocol.UseItemScRsp.init(allocator);
    rsp.use_item_id = req.use_item_id;
    rsp.use_item_count = req.use_item_count;
    rsp.retcode = 0;
    var sync = protocol.SyncLineupNotify.init(allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    sync.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync);
    try session.send(CmdID.CmdUseItemScRsp, rsp);
}
