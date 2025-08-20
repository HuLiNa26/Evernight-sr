const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const Config = @import("../services/config.zig");

const Allocator = std.mem.Allocator;

pub var challenge_node: u32 = 0;
pub var StandardBanner = [_]u32{ 1003, 1004, 1101, 1104, 1209, 1211 };
pub var RateUp = [_]u32{1413};
pub var RateUpFourStars = [_]u32{ 1210, 1108, 1207 };

pub var selected_challenge_id: u32 = 0;
pub var selected_buff_id: u32 = 0;

pub var custom_mode: bool = false;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Test Command for Chat\n", allocator);
}
pub fn challengeNode(session: *Session, _: []const u8, allocator: Allocator) !void {
    if (challenge_node == 0) {
        try commandhandler.sendMessage(session, "Change Challenge Node 2 \n", allocator);
        challenge_node = challenge_node + 1;
    } else {
        try commandhandler.sendMessage(session, "Change Challenge Node 1 \n", allocator);
        challenge_node = challenge_node - 1;
    }
}
pub fn setGachaCommand(session: *Session, args: []const u8, allocator: Allocator) !void {
    var arg_iter = std.mem.splitSequence(u8, args, " ");
    const command = arg_iter.next() orelse {
        try commandhandler.sendMessage(session, "Error: Missing sub-command. Usage: /set <sub-command> [arguments]", allocator);
        return;
    };
    if (std.mem.eql(u8, command, "standard")) {
        try standard(session, &arg_iter, allocator);
    } else if (std.mem.eql(u8, command, "rateup")) {
        const next = arg_iter.next();
        if (next) |rateup_number| {
            if (std.mem.eql(u8, rateup_number, "5")) {
                try gacha5Stars(session, &arg_iter, allocator);
            } else if (std.mem.eql(u8, rateup_number, "4")) {
                try gacha4Stars(session, &arg_iter, allocator);
            } else {
                try commandhandler.sendMessage(session, "Error: Invalid rateup number. Please use 4 (four stars) or 5 (5 stars).", allocator);
            }
        } else {
            try commandhandler.sendMessage(session, "Error: Missing number for rateup. Usage: /set rateup <number>", allocator);
        }
    } else {
        try commandhandler.sendMessage(session, "Error: Unknown sub-command. Available: standard, rateup 5, rateup 4", allocator);
    }
}

fn standard(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [6]u32 = undefined;
    var count: usize = 0;
    while (count < 6) {
        if (arg_iter.next()) |avatar_id_str| {
            const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
                return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
            };
            if (!isValidAvatarId(id)) {
                return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
            }
            avatar_ids[count] = id;
            count += 1;
        } else {
            break;
        }
    }
    if (arg_iter.next() != null or count != 6) {
        return sendErrorMessage(session, "Error: You must provide exactly 6 avatar IDs.", allocator);
    }
    @memcpy(&StandardBanner, &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set standard banner ID to: {d}, {d}, {d}, {d}, {d}, {d}", .{ avatar_ids[0], avatar_ids[1], avatar_ids[2], avatar_ids[3], avatar_ids[4], avatar_ids[5] });
    try commandhandler.sendMessage(session, msg, allocator);
}
fn gacha4Stars(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [3]u32 = undefined;
    var count: usize = 0;
    while (count < 3) {
        if (arg_iter.next()) |avatar_id_str| {
            const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
                return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
            };
            if (!isValidAvatarId(id)) {
                return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
            }
            avatar_ids[count] = id;
            count += 1;
        } else {
            break;
        }
    }
    if (arg_iter.next() != null or count != 3) {
        return sendErrorMessage(session, "Error: You must provide exactly 3 avatar IDs.", allocator);
    }
    @memcpy(&RateUpFourStars, &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set 4 star rate up ID to: {d}, {d}, {d}", .{ avatar_ids[0], avatar_ids[1], avatar_ids[2] });
    try commandhandler.sendMessage(session, msg, allocator);
}
fn gacha5Stars(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [1]u32 = undefined;
    if (arg_iter.next()) |avatar_id_str| {
        const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
            return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
        };
        if (!isValidAvatarId(id)) {
            return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
        }
        avatar_ids[0] = id;
    } else {
        return sendErrorMessage(session, "Error: You must provide a rate-up avatar ID.", allocator);
    }
    if (arg_iter.next() != null) {
        return sendErrorMessage(session, "Error: Only one rate-up avatar ID is allowed.", allocator);
    }
    @memcpy(&RateUp, &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set rate up ID to: {d}", .{avatar_ids[0]});
    try commandhandler.sendMessage(session, msg, allocator);
}
fn sendErrorMessage(session: *Session, message: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, message, allocator);
}
fn isValidAvatarId(avatar_id: u32) bool {
    return avatar_id >= 1000 and avatar_id <= 9999;
}
pub fn onBuffId(session: *Session, input: []const u8, allocator: Allocator) !void {
    if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, input, " "), "info")) {
        return try onBuffInfo(session, allocator);
    }
    var tokens = std.ArrayList([]const u8).init(allocator);
    defer tokens.deinit();
    var iter = std.mem.tokenizeScalar(u8, input, ' ');
    while (iter.next()) |tok| {
        try tokens.append(tok);
    }
    if (tokens.items.len == 0) {
        return sendErrorMessage(session, "Error: Missing command arguments.", allocator);
    }
    if (std.ascii.eqlIgnoreCase(tokens.items[0], "off")) {
        custom_mode = false;
        _ = try commandhandler.sendMessage(session, "Custom mode OFF.", allocator);
        return;
    }
    if (tokens.items.len < 6) {
        return sendErrorMessage(session, "Error: Usage: /id <group_id> floor <n> node <1|2>", allocator);
    }
    const group_id = std.fmt.parseInt(u32, tokens.items[0], 10) catch return sendErrorMessage(session, "Error: Invalid group ID.", allocator);
    if (!std.ascii.eqlIgnoreCase(tokens.items[1], "floor")) return sendErrorMessage(session, "Error: Expected 'floor' keyword.", allocator);
    const floor = std.fmt.parseInt(u32, tokens.items[2], 10) catch return sendErrorMessage(session, "Error: Invalid floor number.", allocator);
    if (!std.ascii.eqlIgnoreCase(tokens.items[3], "node")) return sendErrorMessage(session, "Error: Expected 'node' keyword.", allocator);
    const node = std.fmt.parseInt(u8, tokens.items[4], 10) catch return sendErrorMessage(session, "Error: Invalid node number.", allocator);
    if (node != 1 and node != 2) return sendErrorMessage(session, "Error: Node must be 1 or 2.", allocator);
    challenge_node = node - 1;
    const challenge_mode = switch (group_id / 1000) {
        1 => "MoC",
        2 => "PF",
        3 => "AS",
        else => "Unknown",
    };
    try commandhandler.sendMessage(session, try std.fmt.allocPrint(allocator, "Challenge mode: {s}", .{challenge_mode}), allocator);
    const challenge_config = try Config.loadChallengeConfig(allocator, "resources/ChallengeMazeConfig.json");
    const stage_config = try Config.loadStageConfig(allocator, "resources/StageConfig.json");
    const challenge_entry = for (challenge_config.challenge_config.items) |entry| {
        if (entry.group_id == group_id and entry.floor == floor)
            break entry;
    } else {
        return sendErrorMessage(session, "Error: Could not find matching challenge ID.", allocator);
    };
    if (tokens.items.len > 5) {
        const keyword = tokens.items[5];
        if (std.ascii.eqlIgnoreCase(keyword, "buff")) {
            if (tokens.items.len < 7) {
                return sendErrorMessage(session, "Error: Missing buff sub-command (info/set <index>).", allocator);
            }
            const sub = tokens.items[6];
            if (std.ascii.eqlIgnoreCase(sub, "info")) {
                return sendBuffInfo(session, allocator, group_id, node);
            } else if (std.ascii.eqlIgnoreCase(sub, "set")) {
                return sendErrorMessage(session, "Error: Missing buff index for 'set' command.", allocator);
            } else {
                const buff_index = std.fmt.parseInt(usize, sub, 10) catch {
                    return sendErrorMessage(session, "Error: Invalid buff index.", allocator);
                };
                if (tokens.items.len < 8 or !std.ascii.eqlIgnoreCase(tokens.items[7], "set")) {
                    return sendErrorMessage(session, "Error: Expected 'set' after buff index.", allocator);
                }
                return handleBuffSetCommand(session, allocator, group_id, node, buff_index, challenge_entry.id);
            }
        } else if (std.ascii.eqlIgnoreCase(keyword, "set")) {
            if ((group_id / 1000) != 1) {
                return sendErrorMessage(session, "Error: Unexpected 'set' command. Did you mean 'buff <index> set' ?", allocator);
            }
            try handleMoCSelectChallenge(session, allocator, challenge_entry.id);
            return;
        }
    }
    var event_id: ?u32 = null;
    if (node == 1 and challenge_entry.event_id_list1.items.len > 0) {
        event_id = challenge_entry.event_id_list1.items[0];
    } else if (node == 2 and challenge_entry.event_id_list2.items.len > 0) {
        event_id = challenge_entry.event_id_list2.items[0];
    }
    if (event_id == null) {
        return sendErrorMessage(session, "Error: Could not find matching EventID.", allocator);
    }
    if ((group_id / 1000) == 1) {
        try handleMoCSelectChallenge(session, allocator, challenge_entry.id);
        return;
    }
    for (stage_config.stage_config.items) |stage| {
        if (stage.stage_id == event_id.?) {
            try sendStageInfo(session, allocator, group_id, floor, node, stage);
            return;
        }
    }
    return sendErrorMessage(session, "Error: Stage not found for given EventID.", allocator);
}
fn handleMoCSelectChallenge(session: *Session, allocator: Allocator, challenge_id: u32) !void {
    const line = try std.fmt.allocPrint(allocator, "Selected MoC Challenge ID: {d}", .{challenge_id});
    try commandhandler.sendMessage(session, line, allocator);
    selected_challenge_id = challenge_id;
    selected_buff_id = 0;
    custom_mode = true;
}
fn handleBuffSetCommand(session: *Session, allocator: Allocator, group_id: u32, node: u8, buff_index: usize, challenge_id: u32) !void {
    const buff_config = try Config.loadTextMapConfig(allocator, "resources/BuffInfoConfig.json");
    for (buff_config.text_map_config.items) |entry| {
        if (entry.group_id == group_id) {
            const list = if (node == 1) &entry.buff_list1 else &entry.buff_list2;
            if (buff_index == 0 or buff_index > list.items.len) {
                return sendErrorMessage(session, "Error: Buff index out of range.", allocator);
            }
            const buff = list.items[buff_index - 1];
            const line = try std.fmt.allocPrint(allocator, "Selected Challenge ID: {d}, Buff ID: {d} - {s}", .{ challenge_id, buff.id, buff.name });
            try commandhandler.sendMessage(session, line, allocator);
            selected_challenge_id = challenge_id;
            selected_buff_id = buff.id;
            custom_mode = true;
            return;
        }
    }
    return sendErrorMessage(session, "Error: Buff group ID not found.", allocator);
}
fn sendStageInfo(session: *Session, allocator: Allocator, group_id: u32, floor: u32, node: u8, stage: Config.Stage) !void {
    const header = try std.fmt.allocPrint(allocator, "GroupID: {d}, Floor: {d}, Node: {d}, StageID: {d}", .{ group_id, floor, node, stage.stage_id });
    try commandhandler.sendMessage(session, header, allocator);
    for (stage.monster_list.items, 0..) |wave, i| {
        var msg = try std.fmt.allocPrint(allocator, "wave {d}:", .{i + 1});
        for (wave.items) |monster_id| {
            msg = try std.fmt.allocPrint(allocator, "{s} {d},", .{ msg, monster_id });
        }
        try commandhandler.sendMessage(session, msg, allocator);
    }
}
fn sendBuffInfo(session: *Session, allocator: Allocator, group_id: u32, node: u8) !void {
    const buff_config = try Config.loadTextMapConfig(allocator, "resources/BuffInfoConfig.json");
    for (buff_config.text_map_config.items) |entry| {
        if (entry.group_id == group_id) {
            const list = if (node == 1) &entry.buff_list1 else &entry.buff_list2;
            for (list.items) |buff| {
                const line = try std.fmt.allocPrint(allocator, "id: {d} - {s}", .{ buff.id, buff.name });
                try commandhandler.sendMessage(session, line, allocator);
            }
            return;
        }
    }
    return sendErrorMessage(session, "Error: Buff group ID not found.", allocator);
}
pub fn onBuffInfo(session: *Session, allocator: Allocator) !void {
    const challenge_config = try Config.loadChallengeConfig(allocator, "resources/ChallengeMazeConfig.json");

    var max_moc: u32 = 0;
    var max_pf: u32 = 0;
    var max_as: u32 = 0;

    for (challenge_config.challenge_config.items) |entry| {
        const id = entry.group_id;
        if (id >= 1000 and id < 2000 and id > max_moc) {
            max_moc = id;
        } else if (id >= 2000 and id < 3000 and id > max_pf) {
            max_pf = id;
        } else if (id >= 3000 and id < 4000 and id > max_as) {
            max_as = id;
        }
    }
    const msg = try std.fmt.allocPrint(allocator, "Current Challenge IDs: MoC: {d}, PF: {d}, AS: {d}", .{ max_moc, max_pf, max_as });
    try commandhandler.sendMessage(session, msg, allocator);
}
