const std = @import("std");
const protocol = @import("protocol");
const Config = @import("../data/game_config.zig");
const Data = @import("../data.zig");
const Logic = @import("../utils/logic.zig");
const Uid = @import("../utils/uid.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub var m7th: u32 = 1224;
pub var mc_id: u32 = 8008;

pub fn createAvatar(
    allocator: Allocator,
    avatarConf: Config.Avatar,
) !protocol.Avatar {
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
    if (Logic.inlist(avatar.base_avatar_id, &Data.EnhanceAvatarID)) {
        avatar.unk_enhanced_id = 1;
    }
    avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
    for (1..6) |i| {
        try avatar.has_taken_promotion_reward_list.append(@intCast(i));
    }
    avatar.equipment_unique_id = Uid.nextGlobalId();
    avatar.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
    for (0..6) |i| {
        try avatar.equip_relic_list.append(.{
            .relic_unique_id = Uid.nextGlobalId(),
            .type = @intCast(i),
        });
    }
    try createSkillTree(avatar.base_avatar_id, &avatar.skilltree_list);
    return avatar;
}
pub fn createAllAvatar(
    allocator: Allocator,
    Avatar_id: u32,
) !protocol.Avatar {
    var avatar = protocol.Avatar.init(allocator);
    avatar.base_avatar_id = Avatar_id;
    avatar.level = 80;
    avatar.promotion = 6;
    avatar.rank = 6;
    if (Avatar_id == 1310) avatar.dressed_skin_id = 1131001;
    if (Logic.inlist(avatar.base_avatar_id, &Data.EnhanceAvatarID)) {
        avatar.unk_enhanced_id = 1;
    }
    avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
    for (1..6) |i| {
        try avatar.has_taken_promotion_reward_list.append(@intCast(i));
    }
    try createSkillTree(avatar.base_avatar_id, &avatar.skilltree_list);
    return avatar;
}

fn createSkillTree(
    base_avatar_id: u32,
    skilltree_list: *std.ArrayList(protocol.AvatarSkillTree),
) !void {
    const skill_list: []const u32 = if (Logic.inlist(base_avatar_id, &Data.Rem)) &Data.skills else &Data.skills_old;
    for (skill_list) |elem| {
        const talentLevel: u32 = switch (elem) {
            1 => 6,
            2...4 => 10,
            301, 302 => if (Logic.inlist(base_avatar_id, &Data.Rem)) 6 else 1,
            else => 1,
        };
        const point_id: u32 =
            if (Logic.inlist(base_avatar_id, &Data.EnhanceAvatarID))
                base_avatar_id + 10000
            else
                base_avatar_id;
        const talent = protocol.AvatarSkillTree{
            .point_id = point_id * 1000 + elem,
            .level = talentLevel,
        };
        try skilltree_list.append(talent);
    }
}

pub fn createEquipment(
    lightconeConf: Config.Lightcone,
    dress_avatar_id: u32,
) !protocol.Equipment {
    return protocol.Equipment{
        .unique_id = Uid.nextGlobalId(),
        .tid = lightconeConf.id,
        .is_protected = true,
        .level = lightconeConf.level,
        .rank = lightconeConf.rank,
        .promotion = lightconeConf.promotion,
        .dress_avatar_id = dress_avatar_id,
    };
}

pub fn createRelic(
    allocator: Allocator,
    relicConf: Config.Relic,
    dress_avatar_id: u32,
) !protocol.Relic {
    var r = protocol.Relic{
        .tid = relicConf.id,
        .main_affix_id = relicConf.main_affix_id,
        .unique_id = Uid.nextGlobalId(),
        .exp = 0,
        .dress_avatar_id = dress_avatar_id,
        .is_protected = true,
        .level = relicConf.level,
        .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
        .reforge_sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
    };
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat1, .cnt = relicConf.cnt1, .step = relicConf.step1 });
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat2, .cnt = relicConf.cnt2, .step = relicConf.step2 });
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat3, .cnt = relicConf.cnt3, .step = relicConf.step3 });
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat4, .cnt = relicConf.cnt4, .step = relicConf.step4 });
    return r;
}

pub fn createAllMultiPath(
    allocator: Allocator,
    config: *const Config.GameConfig,
) !ArrayList(protocol.MultiPathAvatarInfo) {
    var multis = ArrayList(protocol.MultiPathAvatarInfo).init(allocator);
    const avatar_ids = [_][]const u32{
        &[_]u32{ 8001, 8002 },
        &[_]u32{ 8003, 8004 },
        &[_]u32{ 8005, 8006 },
        &[_]u32{ 8007, 8008 },
        &[_]u32{1001},
        &[_]u32{1224},
    };
    const avatar_types = [_]protocol.MultiPathAvatarType{
        .GirlWarriorType,
        .GirlKnightType,
        .GirlShamanType,
        .GirlMemoryType,
        .Mar_7thKnightType,
        .Mar_7thRogueType,
    };
    var indexes: [6]u32 = [_]u32{0} ** 6;
    var counts: [6]u32 = [_]u32{0} ** 6;
    var ranks: [6]u32 = [_]u32{0} ** 6;
    for (config.avatar_config.items) |avatar| {
        for (0..avatar_ids.len) |i| {
            counts[i] += 1;
            for (avatar_ids[i]) |id| {
                if (avatar.id == id) {
                    ranks[i] = avatar.rank;
                    indexes[i] = @as(u32, @intCast(config.avatar_config.items.len)) + 1 - counts[i];
                }
            }
        }
    }
    for (0..avatar_types.len) |i| {
        var multi = protocol.MultiPathAvatarInfo.init(allocator);
        multi.rank = ranks[i];
        multi.avatar_id = avatar_types[i];
        if (avatar_types[i] == .Mar_7thKnightType) {
            multi.dressed_skin_id = 1100101;
        }
        var gen = Uid.UidGenerator().init(Uid.getCurrentGlobalId() - (indexes[i] * 7));
        multi.path_equipment_id = gen.nextId();
        multi.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
        for (0..6) |slot| {
            try multi.equip_relic_list.append(.{
                .relic_unique_id = gen.nextId(),
                .type = @intCast(slot),
            });
        }
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
            try multi.multi_path_skill_tree.append(talent);
        }
        try multis.append(multi);
    }
    return multis;
}
