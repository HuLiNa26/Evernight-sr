const std = @import("std");
const protocol = @import("protocol");
const Config = @import("../services/config.zig");
const Data = @import("../data.zig");
const Lineup = @import("../services/lineup.zig");
const ChallengeData = @import("../services/challenge.zig");
const NodeCheck = @import("../commands/value.zig");
const scene_managers = @import("./scene_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub var selectedAvatarID = [_]u32{ 1304, 1313, 1406, 1004 };

fn isInList(id: u32, list: []const u32) bool {
    for (list) |item| {
        if (item == id) {
            return true;
        }
    }
    return false;
}

const Element = enum {
    Physical,
    Fire,
    Ice,
    Thunder,
    Wind,
    Quantum,
    Imaginary,
    None,
};

fn getAvatarElement(avatar_id: u32) Element {
    return switch (avatar_id) {
        1105, 1107, 1111, 1206, 1215, 1221, 1302, 1309, 1315, 1408, 1410, 1414, 8001, 8002 => .Physical,
        1003, 1009, 1109, 1112, 1210, 1218, 1222, 1225, 1301, 1310, 8003, 8004 => .Fire,
        1001, 1013, 1104, 1106, 1209, 1212, 1303, 1312, 1401, 1413, 8007, 8008 => .Ice,
        1005, 1008, 1103, 1202, 1204, 1211, 1223, 1308, 1402 => .Thunder,
        1002, 1014, 1101, 1108, 1205, 1217, 1220, 1307, 1405, 1409, 1412 => .Wind,
        1006, 1015, 1102, 1110, 1201, 1208, 1214, 1306, 1314, 1403, 1406, 1407 => .Quantum,
        1004, 1203, 1207, 1213, 1224, 1304, 1305, 1313, 1317, 1404, 8005, 8006 => .Imaginary,
        else => .None,
    };
}

fn getAttackerBuffId() u32 {
    const avatar_id = selectedAvatarID[Lineup.leader_slot];
    const element = getAvatarElement(avatar_id);
    return switch (element) {
        .Physical => 1000111,
        .Fire => 1000112,
        .Ice => 1000113,
        .Thunder => 1000114,
        .Wind => 1000115,
        .Quantum => 1000116,
        .Imaginary => 1000117,
        .None => 0,
    };
}

fn createBattleRelic(allocator: Allocator, id: u32, level: u32, main_affix_id: u32, stat1: u32, cnt1: u32, step1: u32, stat2: u32, cnt2: u32, step2: u32, stat3: u32, cnt3: u32, step3: u32, stat4: u32, cnt4: u32, step4: u32) !protocol.BattleRelic {
    var relic = protocol.BattleRelic{ .id = id, .main_affix_id = main_affix_id, .level = level, .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator) };
    if (stat1 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat1, .cnt = cnt1, .step = step1 });
    if (stat2 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat2, .cnt = cnt2, .step = step2 });
    if (stat3 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat3, .cnt = cnt3, .step = step3 });
    if (stat4 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat4, .cnt = cnt4, .step = step4 });
    return relic;
}

fn createBattleAvatar(allocator: Allocator, avatarConf: Config.Avatar) !protocol.BattleAvatar {
    var avatar = protocol.BattleAvatar.init(allocator);
    avatar.id = avatarConf.id;
    avatar.hp = avatarConf.hp * 100;
    avatar.sp_bar = .{ .cur_sp = avatarConf.sp * 100, .max_sp = 10000 };
    avatar.level = avatarConf.level;
    avatar.rank = avatarConf.rank;
    avatar.promotion = avatarConf.promotion;
    avatar.avatar_type = .AVATAR_FORMAL_TYPE;
    if (isInList(avatar.id, &Data.EnhanceAvatarID)) avatar.enhanced_id = 1;

    for (avatarConf.relics.items) |relic| {
        const r = try createBattleRelic(allocator, relic.id, relic.level, relic.main_affix_id, relic.stat1, relic.cnt1, relic.step1, relic.stat2, relic.cnt2, relic.step2, relic.stat3, relic.cnt3, relic.step3, relic.stat4, relic.cnt4, relic.step4);
        try avatar.relic_list.append(r);
    }

    const lc = protocol.BattleEquipment{
        .id = avatarConf.lightcone.id,
        .rank = avatarConf.lightcone.rank,
        .level = avatarConf.lightcone.level,
        .promotion = avatarConf.lightcone.promotion,
    };
    try avatar.equipment_list.append(lc);

    var talentLevel: u32 = 0;
    const skill_list: []const u32 = if (isInList(avatar.id, &Data.Rem)) &Data.skills else &Data.skills_old;
    for (skill_list) |elem| {
        talentLevel = switch (elem) {
            1 => 6,
            2...4 => 10,
            301, 302 => if (isInList(avatar.id, &Data.Rem)) 6 else 1,
            else => 1,
        };
        var point_id: u32 = 0;
        if (isInList(avatar.id, &Data.EnhanceAvatarID)) point_id = avatar.id + 10000 else point_id = avatar.id;
        const talent = protocol.AvatarSkillTree{ .point_id = point_id * 1000 + elem, .level = talentLevel };
        try avatar.skilltree_list.append(talent);
    }
    return avatar;
}

const BuffRule = struct {
    avatar_id: u32,
    buffs: []const struct {
        id: u32,
        owner_is_avatar: bool = true,
        dynamic_values: []const protocol.BattleBuff.DynamicValuesEntry = &.{},
    },
};

const technique_buffs = [_]BuffRule{
    .{
        .avatar_id = 1208,
        .buffs = &.{
            .{ .id = 120801, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 120802, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1224,
        .buffs = &.{
            .{ .id = 122402, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 122403, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 122401, .dynamic_values = &.{
                .{ .key = .{ .Const = "#ADF_1" }, .value = 3 },
                .{ .key = .{ .Const = "#ADF_2" }, .value = 3 },
            } },
        },
    },
    .{
        .avatar_id = 1304,
        .buffs = &.{.{ .id = 130403, .dynamic_values = &.{
            .{ .key = .{ .Const = "SkillIndex" }, .value = 3 },
        } }},
    },
    .{
        .avatar_id = 1306,
        .buffs = &.{
            .{ .id = 130601, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 130602, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1309,
        .buffs = &.{
            .{ .id = 130901, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 130902, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1310,
        .buffs = &.{
            .{ .id = 131001, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 131002, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 1000112, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1412,
        .buffs = &.{
            .{ .id = 141201, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 141202, .owner_is_avatar = false, .dynamic_values = &.{
                .{ .key = .{ .Const = "#ADF_1" }, .value = 1 },
                .{ .key = .{ .Const = "#ADF_2" }, .value = 1 },
            } },
        },
    },
};

fn addTechniqueBuffs(allocator: Allocator, battle: *protocol.SceneBattleInfo, avatar: protocol.BattleAvatar, avatarConf: Config.Avatar, avatar_index: u32) !void {
    if (!avatarConf.use_technique) return;

    var targetIndexList = ArrayList(u32).init(allocator);
    errdefer targetIndexList.deinit();
    try targetIndexList.append(0);

    const buffedAvatarId = switch (avatar.id) {
        8004 => 8003,
        8006 => 8005,
        8008 => 8007,
        else => avatar.id,
    };

    if (isInList(buffedAvatarId, &Data.IgnoreToughness)) {
        var buff = protocol.BattleBuff{
            .id = 1000119,
            .level = 1,
            .owner_index = @intCast(avatar_index),
            .wave_flag = 0xFFFFFFFF,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try buff.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(buff);
    }

    var found_custom_buff = false;
    for (technique_buffs) |rule| {
        if (rule.avatar_id == buffedAvatarId) {
            found_custom_buff = true;
            for (rule.buffs) |buff_def| {
                var buff = protocol.BattleBuff{
                    .id = buff_def.id,
                    .level = 1,
                    .owner_index = if (buff_def.owner_is_avatar) @intCast(avatar_index) else Lineup.leader_slot,
                    .wave_flag = 0xFFFFFFFF,
                    .target_index_list = try targetIndexList.clone(),
                    .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
                };
                try buff.dynamic_values.appendSlice(buff_def.dynamic_values);
                try battle.buff_list.append(buff);
            }
            break;
        }
    }
    if (!found_custom_buff) {
        var buff = protocol.BattleBuff{
            .id = buffedAvatarId * 100 + 1,
            .level = 1,
            .owner_index = @intCast(avatar_index),
            .wave_flag = 0xFFFFFFFF,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try buff.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(buff);
    }
    targetIndexList.deinit();
}

fn addGolbalPassive(allocator: Allocator, battle: *protocol.SceneBattleInfo) !void {
    if (isInList(1407, Data.AllAvatars)) {
        var targetIndexList = ArrayList(u32).init(allocator);
        errdefer targetIndexList.deinit();
        try targetIndexList.append(0);
        var mazebuff_data = protocol.BattleBuff{
            .id = 140703,
            .level = 1,
            .owner_index = 1,
            .wave_flag = 0xFFFFFFFF,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try mazebuff_data.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(mazebuff_data);
        targetIndexList.deinit();
    }
}

fn addTriggerAttack(allocator: Allocator, battle: *protocol.SceneBattleInfo) !void {
    var targetIndexList = ArrayList(u32).init(allocator);
    errdefer targetIndexList.deinit();
    try targetIndexList.append(0);
    var attack = protocol.BattleBuff{
        .id = getAttackerBuffId(),
        .level = 1,
        .owner_index = Lineup.leader_slot,
        .wave_flag = 0xFFFFFFFF,
        .target_index_list = try targetIndexList.clone(),
        .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
    };
    try attack.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 1 });
    try battle.buff_list.append(attack);
    targetIndexList.deinit();
}

fn createBattleInfo(allocator: Allocator, config: Config.GameConfig, stage_monster_wave_len: u32, stage_id: u32, rounds_limit: u32) protocol.SceneBattleInfo {
    var battle = protocol.SceneBattleInfo.init(allocator);
    battle.battle_id = config.battle_config.battle_id;
    battle.stage_id = stage_id;
    battle.logic_random_seed = @intCast(@mod(std.time.timestamp(), 0xFFFFFFFF));
    battle.rounds_limit = rounds_limit;
    battle.monster_wave_length = @intCast(stage_monster_wave_len);
    battle.world_level = 6;
    return battle;
}

fn addMonsterWaves(allocator: Allocator, battle: *protocol.SceneBattleInfo, monster_wave_configs: std.ArrayList(std.ArrayList(u32)), monster_level: u32) !void {
    for (monster_wave_configs.items) |wave| {
        var monster_wave = protocol.SceneMonsterWave.init(allocator);
        monster_wave.monster_param = protocol.SceneMonsterWaveParam{ .level = monster_level };
        for (wave.items) |mob_id| {
            try monster_wave.monster_list.append(.{ .monster_id = mob_id });
        }
        try battle.monster_wave_list.append(monster_wave);
    }
}

fn addStageBlessings(allocator: Allocator, battle: *protocol.SceneBattleInfo, blessings: []const u32) !void {
    for (blessings) |blessing| {
        var targetIndexList = ArrayList(u32).init(allocator);
        errdefer targetIndexList.deinit();
        try targetIndexList.append(0);
        var buff = protocol.BattleBuff{
            .id = blessing,
            .level = 1,
            .owner_index = 0xffffffff,
            .wave_flag = 0xffffffff,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try buff.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(buff);
        targetIndexList.deinit();
    }
}

fn addBattleTargets(allocator: Allocator, battle: *protocol.SceneBattleInfo) !void {
    battle.battle_target_info = ArrayList(protocol.SceneBattleInfo.BattleTargetInfoEntry).init(allocator);

    var pfTargetHead = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) };
    if (ChallengeData.on_challenge == true) {
        if (NodeCheck.challenge_node == 0) {
            try pfTargetHead.battle_target_list.append(.{ .id = 10003, .progress = 0, .total_progress = 80000 });
        } else {
            try pfTargetHead.battle_target_list.append(.{ .id = 10003, .progress = 40000, .total_progress = 80000 });
        }
    } else {
        try pfTargetHead.battle_target_list.append(.{ .id = 10002, .progress = 0, .total_progress = 80000 });
    }

    var pfTargetTail = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) };
    try pfTargetTail.battle_target_list.append(.{ .id = 2001, .progress = 0, .total_progress = 0 });
    try pfTargetTail.battle_target_list.append(.{ .id = 2002, .progress = 0, .total_progress = 0 });

    var asTargetHead = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) };
    try asTargetHead.battle_target_list.append(.{ .id = 90005, .progress = 2000, .total_progress = 0 });

    switch (battle.stage_id) {
        30019000...30019100, 30021000...30021100, 30301000...30319000 => { // PF
            try battle.battle_target_info.append(.{ .key = 1, .value = pfTargetHead });
            for (2..4) |i| {
                try battle.battle_target_info.append(.{ .key = @intCast(i), .value = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) } });
            }
            try battle.battle_target_info.append(.{ .key = 5, .value = pfTargetTail });
        },
        420100...420900 => { // AS
            try battle.battle_target_info.append(.{ .key = 1, .value = asTargetHead });
        },
        else => {},
    }
}
fn commonBattleSetup(
    allocator: Allocator,
    battle: *protocol.SceneBattleInfo,
    selected_avatar_ids: []const u32,
    avatar_configs: []const Config.Avatar,
    monster_wave_configs: std.ArrayList(std.ArrayList(u32)),
    monster_level: u32,
    stage_blessings: []const u32,
) !void {
    var avatarIndex: u32 = 0;
    for (selected_avatar_ids) |selected_id| {
        for (avatar_configs) |avatarConf| {
            if (avatarConf.id == selected_id) {
                const avatar = try createBattleAvatar(allocator, avatarConf);
                try addTechniqueBuffs(allocator, battle, avatar, avatarConf, avatarIndex);
                try battle.battle_avatar_list.append(avatar);
                avatarIndex += 1;
                break;
            }
        }
        if (avatarIndex >= 4) break;
    }

    try addMonsterWaves(allocator, battle, monster_wave_configs, monster_level);
    try addTriggerAttack(allocator, battle);
    try addStageBlessings(allocator, battle, stage_blessings);
    try addGolbalPassive(allocator, battle);
    try addBattleTargets(allocator, battle);
}
pub const BattleManager = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) BattleManager {
        return BattleManager{ .allocator = allocator };
    }

    pub fn createBattle(self: *BattleManager) !protocol.SceneBattleInfo {
        var config = try Config.loadGameConfig(self.allocator, "config.json");
        defer config.deinit();

        var battle = createBattleInfo(
            self.allocator,
            config,
            @intCast(config.battle_config.monster_wave.items.len),
            config.battle_config.stage_id,
            config.battle_config.cycle_count,
        );

        try commonBattleSetup(
            self.allocator,
            &battle,
            &selectedAvatarID,
            config.avatar_config.items,
            config.battle_config.monster_wave,
            config.battle_config.monster_level,
            config.battle_config.blessings.items,
        );

        return battle;
    }
};

pub const ChallegeStageManager = struct {
    allocator: Allocator,
    game_config_cache: *scene_managers.GameConfigCache,

    pub fn init(allocator: Allocator, cache: *scene_managers.GameConfigCache) ChallegeStageManager {
        return ChallegeStageManager{
            .allocator = allocator,
            .game_config_cache = cache,
        };
    }

    pub fn createChallegeStage(self: *ChallegeStageManager) !protocol.SceneBattleInfo {
        if (ChallengeData.challenge_stageID == 0) {
            std.log.info("Challenge stage ID is 0, skipping challenge battle creation and returning an empty battle info.", .{});
            return protocol.SceneBattleInfo.init(self.allocator);
        }
        var config = try Config.loadGameConfig(self.allocator, "config.json");
        defer config.deinit();
        const stage_config = &self.game_config_cache.stage_config;
        var battle: protocol.SceneBattleInfo = undefined;
        var found_stage = false;

        for (stage_config.stage_config.items) |stageConf| {
            if (stageConf.stage_id == ChallengeData.challenge_stageID) {
                battle = createBattleInfo(
                    self.allocator,
                    config,
                    @intCast(stageConf.monster_list.items.len),
                    stageConf.stage_id,
                    if (ChallengeData.challenge_mode != 1) 30 else 4,
                );
                found_stage = true;
                try commonBattleSetup(
                    self.allocator,
                    &battle,
                    &selectedAvatarID,
                    config.avatar_config.items,
                    stageConf.monster_list,
                    stageConf.level,
                    ChallengeData.challenge_blessing,
                );
                break;
            }
        }
        if (!found_stage) {
            std.log.err("Challenge stage with ID {d} not found in config.", .{ChallengeData.challenge_stageID});
            return error.StageNotFound;
        }
        return battle;
    }
};

pub fn deinitSceneBattleInfo(battle: *protocol.SceneBattleInfo) void {
    for (battle.battle_avatar_list.items) |*avatar| {
        for (avatar.relic_list.items) |*relic| {
            relic.sub_affix_list.deinit();
        }
        avatar.relic_list.deinit();
        avatar.equipment_list.deinit();
        avatar.skilltree_list.deinit();
    }
    battle.battle_avatar_list.deinit();

    for (battle.buff_list.items) |*buff| {
        buff.target_index_list.deinit();
        buff.dynamic_values.deinit();
    }
    battle.buff_list.deinit();

    for (battle.monster_wave_list.items) |*wave| {
        wave.monster_list.deinit();
    }
    battle.monster_wave_list.deinit();

    for (battle.battle_target_info.items) |*entry| {
        if (entry.value) |*v| {
            v.battle_target_list.deinit();
        }
    }
    battle.battle_target_info.deinit();
}
