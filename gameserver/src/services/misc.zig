const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onPlayerHeartBeat(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerHeartBeatCsReq, allocator);
    defer req.deinit();

    const encoded = "ICAgICAgICBsb2NhbCBmdW5jdGlvbiBzZXRUZXh0Q29tcG9uZW50KHBhdGgsIG5ld1RleHQpDQogICAgICAgICAgICBsb2NhbCBvYmogPSBDUy5Vbml0eUVuZ2luZS5HYW1lT2JqZWN0LkZpbmQocGF0aCkNCiAgICAgICAgICAgIGlmIG9iaiB0aGVuDQogICAgICAgICAgICAgICAgbG9jYWwgdGV4dENvbXBvbmVudCA9IG9iajpHZXRDb21wb25lbnRJbkNoaWxkcmVuKHR5cGVvZihDUy5SUEcuQ2xpZW50LkxvY2FsaXplZFRleHQpKQ0KICAgICAgICAgICAgICAgIGlmIHRleHRDb21wb25lbnQgdGhlbg0KICAgICAgICAgICAgICAgICAgICB0ZXh0Q29tcG9uZW50LnRleHQgPSBuZXdUZXh0DQogICAgICAgICAgICAgICAgZW5kDQogICAgICAgICAgICBlbmQNCiAgICAgICAgZW5kDQogICAgICAgIA0KICAgICAgICBzZXRUZXh0Q29tcG9uZW50KCJVSVJvb3QvQWJvdmVEaWFsb2cvQmV0YUhpbnREaWFsb2coQ2xvbmUpIiwgIjxjb2xvcj0jYjgxNjUxPkV2ZXJuaWdodFNSIGlzIGEgZnJlZSBhbmQgb3BlbiBzb3VyY2Ugc29mdHdhcmUuPC9jb2xvcj4iKQ0KICAgICAgICBzZXRUZXh0Q29tcG9uZW50KCJWZXJzaW9uVGV4dCIsICI8Y29sb3I9I2I4MTY1MT5WaXNpdCBkaXNjb3JkLmdnL3JldmVyc2Vkcm9vbXMgZm9yIG1vcmUgaW5mbyE8L2NvbG9yPiIpDQo=";

    const dest_buf = try allocator.alloc(u8, try std.base64.standard.Decoder.calcSizeForSlice(encoded));
    try std.base64.standard.Decoder.decode(dest_buf, encoded);

    const managed_str = protocol.ManagedString.move(dest_buf, allocator);
    const download_data = protocol.ClientDownloadData{
        .version = 51,
        .time = @intCast(std.time.milliTimestamp()),
        .data = managed_str,
    };

    try session.send(CmdID.CmdPlayerHeartBeatScRsp, protocol.PlayerHeartBeatScRsp{
        .retcode = 0,
        .client_time_ms = req.client_time_ms,
        .server_time_ms = @intCast(std.time.milliTimestamp()),
        .download_data = download_data,
    });
}
