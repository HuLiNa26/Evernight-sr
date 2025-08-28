const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetActivity(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetActivityScheduleConfigScRsp.init(allocator);
    const activity_config = &ConfigManager.global_game_config_cache.activity_config;
    var activ_list = protocol.ActivityScheduleData.init(allocator);
    //challenge mode pannel : 2100101
    for (activity_config.activity_config.items) |activityConf| {
        if (activityConf.panel_id != 30002) {
            activ_list.panel_id = activityConf.activity_id;
            for (activityConf.activity_module_list.items) |id| {
                activ_list.begin_time = 1664308800;
                activ_list.end_time = 4294967295;
                activ_list.activity_id = id;
                try rsp.schedule_data.append(activ_list);
            }
        }
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetActivityScheduleConfigScRsp, rsp);
}

pub fn onUpdateServerPrefsData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.UpdateServerPrefsDataScRsp.init(allocator);
    const req = try packet.getProto(protocol.UpdateServerPrefsDataCsReq, allocator);
    rsp.server_prefs_id = req.server_prefs.?.server_prefs_id;
    rsp.retcode = 0;
    try session.send(CmdID.CmdUpdateServerPrefsDataScRsp, rsp);
}
pub fn onGetActivityHotData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetActivityHotDataScRsp.init(allocator);
    const activity_config = &ConfigManager.global_game_config_cache.activity_config;
    for (activity_config.activity_config.items) |activityConf| {
        if (activityConf.panel_id != 30002) {
            var packaged_list = protocol.GMEBOPMAOFN.init(allocator);
            packaged_list.panel_id = activityConf.panel_id;
            try rsp.content_package_list.append(packaged_list);
        }
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetActivityHotDataScRsp, rsp);
}
