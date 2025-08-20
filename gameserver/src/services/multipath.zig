const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("config.zig");
const Data = @import("../data.zig");
const MultiPathManager = @import("../manager/multipath_mgr.zig").MultiPathManager;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetMultiPathAvatarInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var multipath = MultiPathManager.init(allocator);
    const rsp = try multipath.createMultiPath(1100101);
    try session.send(CmdID.CmdGetMultiPathAvatarInfoScRsp, rsp);
}
