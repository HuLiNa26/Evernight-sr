const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("../services/config.zig");
const Data = @import("../data.zig");
const ChallengeData = @import("../services/challenge.zig");
const NodeCheck = @import("../commands/value.zig");
const BattleManager = @import("../manager/battle_mgr.zig");

const UidGenerator = @import("../services/item.zig").UidGenerator;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

// Function to check if a list contatin an ID
fn containsAny(list: []const u32, ids: []const u32) bool {
    for (ids) |id| {
        for (list) |item| {
            if (item == id) {
                return true;
            }
        }
    }
    return false;
}
pub var mc_id: u32 = 8008;
pub var m7th: u32 = 1224;

pub const LineupManager = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) LineupManager {
        return LineupManager{ .allocator = allocator };
    }
    pub fn createLineup(self: *LineupManager) !protocol.LineupInfo {
        const config = try Config.loadGameConfig(self.allocator, "config.json");

        var lineup = protocol.LineupInfo.init(self.allocator);
        lineup.mp = 5;
        lineup.max_mp = 5;
        lineup.name = .{ .Const = "EvernightSR" };

        for (config.avatar_config.items, 0..) |avatarConf, idx| {
            if (idx >= 4) {
                break;
            }
            var avatar = protocol.LineupAvatar.init(self.allocator);
            avatar.id = avatarConf.id;
            if (avatarConf.id == 1408) {
                lineup.mp = 7;
                lineup.max_mp = 7;
            }
            avatar.slot = @intCast(idx);
            avatar.satiety = 0;
            avatar.hp = avatarConf.hp * 100;
            avatar.sp_bar = .{ .cur_sp = avatarConf.sp * 100, .max_sp = 10000 };
            avatar.avatar_type = protocol.AvatarType.AVATAR_FORMAL_TYPE;
            try lineup.avatar_list.append(avatar);
        }
        var id_list = try self.allocator.alloc(u32, config.avatar_config.items.len);
        defer self.allocator.free(id_list);
        for (config.avatar_config.items, 0..) |slot, idx| {
            if (idx >= 4) {
                break;
            }
            id_list[idx] = slot.id;
        }
        try getSelectedAvatarID(self.allocator, id_list);
        return lineup;
    }
};

pub fn deinitLineupInfo(lineup: *protocol.LineupInfo) void {
    lineup.avatar_list.deinit();
}

pub const ChallengeLineupManager = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) ChallengeLineupManager {
        return ChallengeLineupManager{ .allocator = allocator };
    }
    pub fn createPeakLineup(
        self: *ChallengeLineupManager,
        avatar_list: ArrayList(u32),
    ) !protocol.LineupInfo {
        var lineup = protocol.LineupInfo.init(self.allocator);
        lineup.mp = 5;
        lineup.max_mp = 5;
        lineup.extra_lineup_type = protocol.ExtraLineupType.LINEUP_CHALLENGE;

        for (avatar_list.items, 0..) |avatarlist, idx| {
            var avatar = protocol.LineupAvatar.init(self.allocator);
            avatar.id = avatarlist;
            if (avatarlist == 1408) {
                lineup.mp = 7;
                lineup.max_mp = 7;
            }
            avatar.slot = @intCast(idx);
            avatar.satiety = 0;
            avatar.hp = 10000;
            avatar.sp_bar = .{ .cur_sp = 10000, .max_sp = 10000 };
            avatar.avatar_type = protocol.AvatarType.AVATAR_FORMAL_TYPE;
            try lineup.avatar_list.append(avatar);
        }
        var id_list = try self.allocator.alloc(u32, avatar_list.items.len);
        defer self.allocator.free(id_list);
        for (avatar_list.items, 0..) |slot, idx| {
            if (idx >= 4) {
                break;
            }
            id_list[idx] = slot;
        }
        try getSelectedAvatarID(self.allocator, id_list);
        return lineup;
    }
    pub fn createLineup(
        self: *ChallengeLineupManager,
        avatar_list: ArrayList(u32),
    ) !protocol.LineupInfo {
        var lineup = protocol.LineupInfo.init(self.allocator);
        lineup.mp = 5;
        lineup.max_mp = 5;
        lineup.extra_lineup_type = if (NodeCheck.challenge_node == 0) protocol.ExtraLineupType.LINEUP_CHALLENGE else protocol.ExtraLineupType.LINEUP_CHALLENGE_2;

        for (avatar_list.items, 0..) |avatarlist, idx| {
            var avatar = protocol.LineupAvatar.init(self.allocator);
            avatar.id = avatarlist;
            if (avatarlist == 1408) {
                lineup.mp = 7;
                lineup.max_mp = 7;
            }
            avatar.slot = @intCast(idx);
            avatar.satiety = 0;
            avatar.hp = 10000;
            avatar.sp_bar = .{ .cur_sp = 10000, .max_sp = 10000 };
            avatar.avatar_type = protocol.AvatarType.AVATAR_FORMAL_TYPE;
            try lineup.avatar_list.append(avatar);
        }
        var id_list = try self.allocator.alloc(u32, avatar_list.items.len);
        defer self.allocator.free(id_list);
        for (avatar_list.items, 0..) |slot, idx| {
            if (idx >= 4) {
                break;
            }
            id_list[idx] = slot;
        }
        try getSelectedAvatarID(self.allocator, id_list);
        return lineup;
    }
};

pub fn deinitChallengeLineupInfo(lineup: *protocol.LineupInfo) void {
    lineup.avatar_list.deinit();
}

pub fn getSelectedAvatarID(allocator: std.mem.Allocator, input: []const u32) !void {
    var tempList = std.ArrayList(u32).init(allocator);
    defer tempList.deinit();

    try tempList.appendSlice(input);
    for (tempList.items) |*item| {
        if (item.* == 8001) {
            item.* = mc_id;
        }
        if (item.* == 1001) {
            item.* = m7th;
        }
    }
    var i: usize = 0;
    while (i < BattleManager.selectedAvatarID.len and i < tempList.items.len) : (i += 1) {
        BattleManager.selectedAvatarID[i] = tempList.items[i];
    }
    while (i < BattleManager.selectedAvatarID.len) : (i += 1) {
        BattleManager.selectedAvatarID[i] = 0;
    }
}
