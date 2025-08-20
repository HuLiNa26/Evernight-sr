const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const Packet = @import("../Packet.zig");
const Config = @import("../services/config.zig");
const Item = @import("../services/item.zig");
const Data = @import("../data.zig");
const LineupData = @import("../manager/lineup_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

// function to check the list if true
fn isInList(id: u32, list: []const u32) bool {
    for (list) |item| {
        if (item == id) {
            return true;
        }
    }
    return false;
}

pub var max_avatar_list: u32 = 0;
pub var initial_uid: u32 = 0;

fn syncItems(session: *Session, allocator: Allocator, equip_avatar: bool) !void {
    resetGlobalUidGens();
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    var config = try Config.loadGameConfig(allocator, "config.json");
    defer config.deinit();

    for (config.avatar_config.items) |avatarConf| {
        const dress_avatar_id: u32 = if (equip_avatar) avatarConf.id else 0;
        const lc = protocol.Equipment{
            .unique_id = if (equip_avatar) nextGlobalId() else nextGlobalId(),
            .tid = avatarConf.lightcone.id,
            .is_protected = true,
            .level = avatarConf.lightcone.level,
            .rank = avatarConf.lightcone.rank,
            .promotion = avatarConf.lightcone.promotion,
            .dress_avatar_id = dress_avatar_id,
        };
        try sync.equipment_list.append(lc);

        for (avatarConf.relics.items) |input| {
            var r = protocol.Relic{
                .tid = input.id,
                .main_affix_id = input.main_affix_id,
                .unique_id = if (equip_avatar) nextGlobalId() else nextGlobalId(),
                .exp = 0,
                .dress_avatar_id = dress_avatar_id,
                .is_protected = true,
                .level = input.level,
                .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
                .reforge_sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
            };
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat1, .cnt = input.cnt1, .step = input.step1 });
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat2, .cnt = input.cnt2, .step = input.step2 });
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat3, .cnt = input.cnt3, .step = input.step3 });
            try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = input.stat4, .cnt = input.cnt4, .step = input.step4 });
            try sync.relic_list.append(r);
        }
    }
    if (!equip_avatar) {
        const getcurrent_uid = getCurrentGlobalId();
        initial_uid = getcurrent_uid;
    }
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}

pub fn onUndressEquipment(session: *Session, _: []const u8, allocator: Allocator) !void {
    try syncItems(session, allocator, false);
}
pub fn onSyncEquipment(session: *Session, _: []const u8, allocator: Allocator) !void {
    try syncItems(session, allocator, true);
}

pub fn onSyncAvatar(session: *Session, _: []const u8, allocator: Allocator) !void {
    resetGlobalUidGens();
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    var config = try Config.loadGameConfig(allocator, "config.json");
    defer config.deinit();
    var char = protocol.AvatarSync.init(allocator);
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
        try char.avatar_list.append(avatar);
    }
    // rewrite data of avatar in config
    for (config.avatar_config.items) |avatarConf| {
        var avatar = protocol.Avatar.init(allocator);
        // basic info
        avatar.base_avatar_id = switch (avatarConf.id) {
            8001...8008 => 8001,
            1224 => 1001,
            else => avatarConf.id,
        };
        avatar.level = avatarConf.level;
        avatar.promotion = avatarConf.promotion;
        avatar.rank = avatarConf.rank;
        if (isInList(avatar.base_avatar_id, &Data.EnhanceAvatarID)) avatar.unk_enhanced_id = 1;
        avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
        for (1..6) |i| {
            try avatar.has_taken_promotion_reward_list.append(@intCast(i));
        }
        avatar.equipment_unique_id = nextGlobalId();
        avatar.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
        for (0..6) |i| {
            try avatar.equip_relic_list.append(.{
                .relic_unique_id = nextGlobalId(), // uid
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
        try char.avatar_list.append(avatar);
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
    max_avatar_list = @intCast(config.avatar_config.items.len);
    sync.avatar_sync = char;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}
// TODO: DO WITH MALE MC TOO :Đ
pub fn onSyncMultiPath(session: *Session, _: []const u8, allocator: Allocator) !void {
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    var config = try Config.loadGameConfig(allocator, "config.json");
    defer config.deinit();
    const currentAvatarId = getCurrentGlobalId();
    const GeneratorType = UidGen();
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
                    indexes[i] = max_avatar_list + 1 - counts[i];
                }
            }
        }
    }
    var generators: [6]GeneratorType = undefined;
    for (0..multis.len) |i| {
        generators[i] = GeneratorType.init(currentAvatarId - (indexes[i] * 7) + 1);
    }
    for (0..multis.len) |i| {
        var multi = &multis[i];
        var gen = &generators[i];

        multi.path_equipment_id = currentAvatarId - (indexes[i] * 7) + 1;
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
    try sync.multi_path_avatar_info_list.appendSlice(&multis);
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}

pub var global_uid_gen: UidGenerator = undefined;

fn resetGlobalUidGens() void {
    global_uid_gen = UidGenerator.init(initial_uid);
}

pub fn nextGlobalId() u32 {
    return global_uid_gen.nextId();
}

pub fn getCurrentGlobalId() u32 {
    return global_uid_gen.getCurrentId();
}

pub const UidGenerator = struct {
    current_id: u32,

    pub fn init(start_id: u32) UidGenerator {
        return UidGenerator{ .current_id = start_id };
    }

    pub fn nextId(self: *UidGenerator) u32 {
        self.current_id += 1;
        return self.current_id;
    }

    pub fn getCurrentId(self: *const UidGenerator) u32 {
        return self.current_id;
    }
};

pub fn UidGen() type {
    return struct {
        current_id: u32,
        const Self = @This();

        pub fn init(start_id: u32) Self {
            return Self{ .current_id = start_id };
        }

        pub fn nextId(self: *Self) u32 {
            self.current_id += 1;
            return self.current_id;
        }

        pub fn getCurrentId(self: *const Self) u32 {
            return self.current_id;
        }
    };
}
pub fn onGenerateAndSync(session: *Session, placeholder: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Sync items with config\n", allocator);
    try syncItems(session, allocator, false);
    try syncItems(session, allocator, true);
    try onSyncAvatar(session, placeholder, allocator);
    try onSyncMultiPath(session, placeholder, allocator);
}
