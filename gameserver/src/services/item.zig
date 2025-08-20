const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("config.zig");
const Data = @import("../data.zig");
const LineupManager = @import("../manager/lineup_mgr.zig").LineupManager;
const Sync = @import("../commands/sync.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetBag(session: *Session, _: *const Packet, allocator: Allocator) !void {
    const config = try Config.loadGameConfig(allocator, "config.json");
    var generator = UidGenerator().init();
    // fake item inventory
    // TODO: make real one
    var rsp = protocol.GetBagScRsp.init(allocator);
    rsp.equipment_list = ArrayList(protocol.Equipment).init(allocator);
    rsp.relic_list = ArrayList(protocol.Relic).init(allocator);

    for (Data.ItemList) |tid| {
        try rsp.material_list.append(.{ .tid = tid, .num = 100 });
    }

    for (config.avatar_config.items) |avatarConf| {
        // lc
        const lc = protocol.Equipment{
            .unique_id = generator.nextId(),
            .tid = avatarConf.lightcone.id, // id
            .is_protected = true, // lock
            .level = avatarConf.lightcone.level,
            .rank = avatarConf.lightcone.rank,
            .promotion = avatarConf.lightcone.promotion,
            .dress_avatar_id = avatarConf.id, // base avatar id
        };
        try rsp.equipment_list.append(lc);

        // relics
        for (avatarConf.relics.items) |input| {
            var r = protocol.Relic{
                .tid = input.id, // id
                .main_affix_id = input.main_affix_id,
                .unique_id = generator.nextId(),
                .exp = 0,
                .dress_avatar_id = avatarConf.id, // base avatar id
                .is_protected = true, // lock
                .level = input.level,
                .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
                .reforge_sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
            };
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat1, .cnt = input.cnt1, .step = input.step1 });
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat2, .cnt = input.cnt2, .step = input.step2 });
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat3, .cnt = input.cnt3, .step = input.step3 });
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat4, .cnt = input.cnt4, .step = input.step4 });
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
    var lineup_mgr = LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    sync.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync);
    try session.send(CmdID.CmdUseItemScRsp, rsp);
}

pub fn UidGenerator() type {
    return struct {
        current_id: u32,

        const Self = @This();

        pub fn init() Self {
            return Self{ .current_id = 0 };
        }
        pub fn curId(self: *const Self) u32 {
            return self.current_id;
        }
        pub fn nextId(self: *Self) u32 {
            self.current_id +%= 1; // Using wrapping addition
            return self.current_id;
        }
    };
}
