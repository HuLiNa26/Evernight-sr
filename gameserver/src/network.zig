const std = @import("std");
const Session = @import("Session.zig");
const ConfigManager = @import("../src/manager/config_mgr.zig");
const Allocator = std.mem.Allocator;

pub fn listen() !void {
    const addr = std.net.Address.parseIp4("0.0.0.0", 23301) catch unreachable;
    var listener = try addr.listen(.{
        .kernel_backlog = 100,
        .reuse_address = true,
    });

    std.log.info("server is listening at {}", .{listener.listen_address});

    while (true) {
        const conn = listener.accept() catch continue;
        errdefer conn.stream.close();

        const thread = try std.Thread.spawn(.{}, runSession, .{
            conn.address,
            conn.stream,
            ConfigManager.global_main_allocator,
            &ConfigManager.global_game_config_cache,
        });
        thread.detach();
    }
}

fn runSession(
    address: std.net.Address,
    stream: std.net.Stream,
    main_allocator: Allocator,
    game_config_cache: *ConfigManager.GameConfigCache,
) !void {
    std.log.info("new connection from {}", .{address});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.log.err("memory leaks were detected for session at {}", .{address});

    const session_allocator = gpa.allocator();

    const session = try session_allocator.create(Session);
    session.* = Session.init(address, stream, session_allocator, main_allocator, game_config_cache);

    if (session.*.run()) |_| {
        std.log.info("client from {} disconnected", .{address});
    } else |err| {
        std.log.err("session disconnected with an error: {}", .{err});
    }

    session_allocator.destroy(session);
}
