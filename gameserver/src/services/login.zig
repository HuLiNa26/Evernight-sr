const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const CmdID = protocol.CmdID;

const content = [_]u32{
    200001, 200002, 200003, 200004, 200005, 200006, 200007,
    150017, 150015, 150021, 150018, 130011, 130012, 130013,
    150025, 140006, 150026, 130014, 150034, 150029, 150035,
    150041, 150039, 150045, 150057, 150042, 150067, 150064,
    150063,
};

pub fn onPlayerGetToken(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.PlayerGetTokenScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.uid = 1;

    try session.send(CmdID.CmdPlayerGetTokenScRsp, rsp);
}

pub fn onPlayerLogin(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerLoginCsReq, allocator);

    var basic_info = protocol.PlayerBasicInfo.init(allocator);
    basic_info.stamina = 300;
    basic_info.level = 70;
    basic_info.nickname = .{ .Const = "ReversedRooms" };
    basic_info.world_level = 6;
    basic_info.mcoin = 99999990;
    basic_info.hcoin = 99999990; //Jade
    basic_info.scoin = 99999990; //Money

    var rsp = protocol.PlayerLoginScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.login_random = req.login_random;
    rsp.stamina = 300;
    rsp.basic_info = basic_info;

    try session.send(CmdID.CmdPlayerLoginScRsp, rsp);
}

pub fn onPlayerLoginFinish(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var package_data = protocol.ContentPackageData.init(allocator);
    package_data.cur_content_id = 0;
    for (content) |id| {
        try package_data.content_package_list.append(protocol.ContentPackageInfo{
            .content_id = id,
            .status = protocol.ContentPackageStatus.ContentPackageStatus_Finished,
        });
    }

    var noti = protocol.UnlockAvatarSkinScNotify.init(allocator);
    noti.skin_id = 1100101;
    noti.skin_id = 1131001;
    try session.send(CmdID.CmdUnlockAvatarSkinScNotify, noti);
    var phone = protocol.UnlockPhoneCaseScNotify.init(allocator);
    phone.phone_case_id = 254000;
    try session.send(CmdID.CmdUnlockPhoneCaseScNotify, phone);
    try session.send(CmdID.CmdContentPackageSyncDataScNotify, protocol.ContentPackageSyncDataScNotify{
        .data = package_data,
    });
    try session.send(CmdID.CmdPlayerLoginFinishScRsp, protocol.PlayerLoginFinishScRsp{
        .retcode = 0,
    });
}

pub fn onContentPackageGetData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.ContentPackageGetDataScRsp.init(allocator);
    rsp.retcode = 0;
    var package_data = protocol.ContentPackageData.init(allocator);
    package_data.cur_content_id = 0;
    for (content) |id| {
        try package_data.content_package_list.append(protocol.ContentPackageInfo{
            .content_id = id,
            .status = protocol.ContentPackageStatus.ContentPackageStatus_Finished,
        });
    }
    try session.send(CmdID.CmdContentPackageGetDataScRsp, rsp);
}

pub fn onSetClientPaused(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetClientPausedCsReq, allocator);
    try session.send(CmdID.CmdSetClientPausedScRsp, protocol.SetClientPausedScRsp{
        .retcode = 0,
        .paused = req.paused,
    });
}
