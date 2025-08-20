const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("../services/config.zig");
const Data = @import("../data.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub const MultiPathManager = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) MultiPathManager {
        return MultiPathManager{ .allocator = allocator };
    }
    pub fn createMultiPath(self: *MultiPathManager, skinID: u32) !protocol.GetMultiPathAvatarInfoScRsp {
        var rsp = protocol.GetMultiPathAvatarInfoScRsp.init(self.allocator);
        const config = try Config.loadGameConfig(self.allocator, "config.json");
        const GeneratorType = UidGenerator();
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
            multi.* = protocol.MultiPathAvatarInfo.init(self.allocator);
            multi.avatar_id = avatar_type;
            if (avatar_type == .Mar_7thKnightType) {
                multi.dressed_skin_id = skinID;
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
            multi.equip_relic_list = ArrayList(protocol.EquipRelic).init(self.allocator);

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
        try rsp.cur_multi_path_avatar_type_map.append(.{ .key = 1001, .value = .Mar_7thKnightType });
        try rsp.cur_multi_path_avatar_type_map.append(.{ .key = 8001, .value = .GirlMemoryType });
        rsp.retcode = 0;

        return rsp;
    }
};

pub fn UidGenerator() type {
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
