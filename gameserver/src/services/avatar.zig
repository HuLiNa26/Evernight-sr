const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("config.zig");
const Data = @import("../data.zig");
const LineupData = @import("../manager/lineup_mgr.zig");

const UidGenerator = @import("item.zig").UidGenerator;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub var m7th: bool = true;
pub var mg: bool = true;
pub var mac: u32 = 4;

// function to check the list if true
fn isInList(id: u32, list: []const u32) bool {
    for (list) |item| {
        if (item == id) {
            return true;
        }
    }
    return false;
}
fn MultiPathUidGenerator() type {
    return struct {
        current_id: u32,
        const Self = @This();
        pub fn init(initial_id: u32) Self {
            return Self{ .current_id = initial_id };
        }
        pub fn nextId(self: *Self) u32 {
            self.current_id +%= 1;
            return self.current_id;
        }
    };
}

pub fn onGetAvatarData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    var config = try Config.loadGameConfig(allocator, "config.json");
    defer config.deinit();
    var generator = UidGenerator().init();
    const req = try packet.getProto(protocol.GetAvatarDataCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.GetAvatarDataScRsp.init(allocator);
    const GeneratorType = MultiPathUidGenerator();
    const avatar_ids = [_][]const u32{
        &[_]u32{ 8001, 8002 },
        &[_]u32{ 8003, 8004 },
        &[_]u32{ 8005, 8006 },
        &[_]u32{ 8007, 8008 },
        &[_]u32{1001},
        &[_]u32{1224},
    };
    const avatar_types = [_]protocol.MultiPathAvatarType{
        .GirlWarriorType, .GirlKnightType,    .GirlShamanType,
        .GirlMemoryType,  .Mar_7thKnightType, .Mar_7thRogueType,
    };
    var indexes: [6]u32 = [_]u32{0} ** 6;
    var counts: [6]u32 = [_]u32{0} ** 6;
    var multis: [6]protocol.MultiPathAvatarInfo = undefined;
    for (&multis, avatar_types, 0..) |*multi, avatar_type, i| {
        std.debug.print("MULTIPATH AVATAR INDEX: {} IS {}\n", .{ i, avatar_type });
        multi.* = protocol.MultiPathAvatarInfo.init(allocator);
        multi.avatar_id = avatar_type;
        if (avatar_type == .Mar_7thKnightType) {
            multi.dressed_skin_id = 1100101;
        }
    }
    for (config.avatar_config.items) |avatar| {
        for (0..avatar_ids.len) |i| {
            counts[i] += 1;
            for (avatar_ids[i]) |id| {
                if (avatar.id == id) {
                    multis[i].rank = avatar.rank;
                    indexes[i] = counts[i] - 1;
                }
            }
        }
    }
    var generators: [6]GeneratorType = undefined;
    for (0..multis.len) |i| {
        generators[i] = GeneratorType.init(indexes[i] * 7 + 1);
    }
    for (0..multis.len) |i| {
        var multi = &multis[i];
        var gen = &generators[i];

        multi.path_equipment_id = indexes[i] * 7 + 1;
        multi.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);

        for (0..6) |slot| {
            try multi.equip_relic_list.append(.{
                .relic_unique_id = gen.nextId(),
                .type = @intCast(slot),
            });
        }
    }
    for (0..multis.len) |i| {
        const skill_set = if (i == 3) &Data.skills else &Data.skills_old;
        for (skill_set) |skill| {
            const talent_level: u32 = if (skill == 1 or skill == 301 or skill == 302) 6 else if (skill <= 4) 10 else 1;
            const point_id = if (avatar_ids[i].len > 1)
                avatar_ids[i][1] * 1000 + skill
            else
                avatar_ids[i][0] * 1000 + skill;
            const talent = protocol.AvatarSkillTree{
                .point_id = point_id,
                .level = talent_level,
            };
            try multis[i].multi_path_skill_tree.append(talent);
        }
    }
    try rsp.multi_path_avatar_info_list.appendSlice(&multis);
    try rsp.basic_type_id_list.appendSlice(&Data.MultiAvatar);
    try rsp.cur_avatar_path.append(.{ .key = 1001, .value = .Mar_7thKnightType });
    try rsp.cur_avatar_path.append(.{ .key = 8001, .value = .GirlMemoryType });

    rsp.is_get_all = req.is_get_all;
    for (Data.AllAvatars) |id| {
        var avatar = protocol.Avatar.init(allocator);
        avatar.base_avatar_id = id;
        avatar.level = 80;
        avatar.promotion = 6;
        avatar.rank = 6;
        avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
        for (1..6) |i| {
            try avatar.has_taken_promotion_reward_list.append(@intCast(i));
        }
        var talentLevel: u32 = 0;
        const skill_list: []const u32 = if (isInList(avatar.base_avatar_id, &Data.Rem)) &Data.skills else &Data.skills_old;
        for (skill_list) |elem| {
            talentLevel = switch (elem) {
                1 => 6,
                2...4 => 10,
                301, 302 => if (isInList(avatar.base_avatar_id, &Data.Rem)) 6 else 1,
                else => 1,
            };
            const talent = protocol.AvatarSkillTree{ .point_id = avatar.base_avatar_id * 1000 + elem, .level = talentLevel };
            try avatar.skilltree_list.append(talent);
        }
        try rsp.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        var avatar = protocol.Avatar.init(allocator);
        avatar.base_avatar_id = switch (avatarConf.id) {
            8001...8008 => 8001,
            1224 => 1001,
            else => avatarConf.id,
        };
        avatar.level = avatarConf.level;
        avatar.promotion = avatarConf.promotion;
        avatar.rank = avatarConf.rank;
        if (avatarConf.id == 1310) avatar.dressed_skin_id = 1131001;

        if (isInList(avatar.base_avatar_id, &Data.EnhanceAvatarID)) {
            avatar.unk_enhanced_id = 1;
        }
        avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
        for (1..6) |i| {
            try avatar.has_taken_promotion_reward_list.append(@intCast(i));
        }
        avatar.equipment_unique_id = generator.nextId();
        avatar.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
        for (0..6) |i| {
            try avatar.equip_relic_list.append(.{
                .relic_unique_id = generator.nextId(), // uid
                .type = @intCast(i), // slot
            });
        }
        var talentLevel: u32 = 0;
        const skill_list: []const u32 = if (isInList(avatar.base_avatar_id, &Data.Rem)) &Data.skills else &Data.skills_old;
        for (skill_list) |elem| {
            talentLevel = switch (elem) {
                1 => 6,
                2...4 => 10,
                301, 302 => if (isInList(avatar.base_avatar_id, &Data.Rem)) 6 else 1,
                else => 1,
            };
            var point_id: u32 = 0;
            if (isInList(avatar.base_avatar_id, &Data.EnhanceAvatarID)) point_id = avatar.base_avatar_id + 10000 else point_id = avatar.base_avatar_id;
            const talent = protocol.AvatarSkillTree{ .point_id = point_id * 1000 + elem, .level = talentLevel };
            try avatar.skilltree_list.append(talent);
        }
        try rsp.avatar_list.append(avatar);
        const avatarType: protocol.MultiPathAvatarType = @enumFromInt(avatarConf.id);
        if (avatarConf.id >= 8001 and avatarConf.id <= 8008) {
            LineupData.mc_id = avatarConf.id;
        }
        if (avatarConf.id == 1001 or avatarConf.id == 1224) {
            LineupData.m7th = avatarConf.id;
        }
        if (@intFromEnum(avatarType) > 1) {
            try session.send(CmdID.CmdSetAvatarPathScRsp, protocol.SetAvatarPathScRsp{
                .retcode = 0,
                .avatar_id = avatarType,
            });
        }
    }
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
        m7th = false;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.Mar_7thRogueType) {
        m7th = true;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.BoyWarriorType) {
        mac = 1;
        mg = false;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.BoyKnightType) {
        mac = 2;
        mg = false;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.BoyShamanType) {
        mac = 3;
        mg = false;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.BoyMemoryType) {
        mac = 4;
        mg = false;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlWarriorType) {
        mac = 1;
        mg = true;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlKnightType) {
        mac = 2;
        mg = true;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlShamanType) {
        mac = 3;
        mg = true;
    } else if (rsp.avatar_id == protocol.MultiPathAvatarType.GirlMemoryType) {
        mac = 4;
        mg = true;
    }

    var sync = protocol.AvatarPathChangedNotify.init(allocator);

    if (req.avatar_id == protocol.MultiPathAvatarType.GirlMemoryType) {
        sync.base_avatar_id = 8008;
    } else if (req.avatar_id == protocol.MultiPathAvatarType.GirlShamanType) {
        sync.base_avatar_id = 8006;
    } else if (req.avatar_id == protocol.MultiPathAvatarType.GirlKnightType) {
        sync.base_avatar_id = 8004;
    } else if (req.avatar_id == protocol.MultiPathAvatarType.GirlWarriorType) {
        sync.base_avatar_id = 8002;
    }
    sync.cur_multi_path_avatar_type = req.avatar_id;

    try session.send(CmdID.CmdAvatarPathChangedNotify, sync);
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
