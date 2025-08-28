const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../session.zig");
const Packet = @import("../Packet.zig");

pub const GameConfig = @import("../data/game_config.zig");
pub const StageConfig = @import("../data/stage_config.zig");
pub const ChallengeConfig = @import("../data/challenge_config.zig");
pub const MiscConfig = @import("../data/misc_config.zig");
pub const ResConfig = @import("../data/res_config.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const GameConfigCache = struct {
    allocator: Allocator,
    game_config: GameConfig.GameConfig,
    res_config: ResConfig.SceneConfig,
    map_entrance_config: MiscConfig.MapEntranceConfig,
    maze_config: MiscConfig.MazePlaneConfig,
    stage_config: StageConfig.StageConfig,
    anchor_config: ResConfig.SceneAnchorConfig,
    quest_config: MiscConfig.QuestConfig,
    challenge_maze_config: ChallengeConfig.ChallengeMazeConfig,
    challenge_peak_config: ChallengeConfig.ChallengePeakConfig,
    challenge_peak_group_config: ChallengeConfig.ChallengePeakGroupConfig,
    challenge_peak_boss_config: ChallengeConfig.ChallengePeakBossConfig,
    activity_config: MiscConfig.ActivityConfig,
    main_mission_config: MiscConfig.MainMissionConfig,
    tutorial_guide_config: MiscConfig.TutorialGuideConfig,
    tutorial_config: MiscConfig.TutorialConfig,
    player_icon_config: MiscConfig.PlayerIconConfig,
    buff_info_config: MiscConfig.TextMapConfig,

    pub fn init(allocator: Allocator) !GameConfigCache {
        const game_cfg = try loadConfig(GameConfig.GameConfig, GameConfig.parseConfig, allocator, "config.json");
        const res_cfg = try loadConfig(ResConfig.SceneConfig, ResConfig.parseAnchor, allocator, "resources/res.json");
        const map_entr_cfg = try loadConfig(MiscConfig.MapEntranceConfig, MiscConfig.parseMapEntranceConfig, allocator, "resources/MapEntrance.json");
        const maze_cfg = try loadConfig(MiscConfig.MazePlaneConfig, MiscConfig.parseMazePlaneConfig, allocator, "resources/MazePlane.json");
        const stage_cfg = try loadConfig(StageConfig.StageConfig, StageConfig.parseStageConfig, allocator, "resources/StageConfig.json");
        const anchor_cfg = try loadConfig(ResConfig.SceneAnchorConfig, ResConfig.parseAnchorConfig, allocator, "resources/Anchor.json");
        const quest_cfg = try loadConfig(MiscConfig.QuestConfig, MiscConfig.parseQuestConfig, allocator, "resources/QuestData.json");
        const challenge_maze_cfg = try loadConfig(ChallengeConfig.ChallengeMazeConfig, ChallengeConfig.parseChallengeConfig, allocator, "resources/ChallengeMazeConfig.json");
        const challenge_peak_cfg = try loadConfig(ChallengeConfig.ChallengePeakConfig, ChallengeConfig.parseChallengePeakConfig, allocator, "resources/ChallengePeakConfig.json");
        const challenge_peak_group_cfg = try loadConfig(ChallengeConfig.ChallengePeakGroupConfig, ChallengeConfig.parseChallengePeakGroupConfig, allocator, "resources/ChallengePeakGroupConfig.json");
        const challenge_peak_boss_cfg = try loadConfig(ChallengeConfig.ChallengePeakBossConfig, ChallengeConfig.parseChallengePeakBossConfig, allocator, "resources/ChallengePeakBossConfig.json");
        const activity_cfg = try loadConfig(MiscConfig.ActivityConfig, MiscConfig.parseActivityConfig, allocator, "resources/ActivityConfig.json");
        const main_mission_cfg = try loadConfig(MiscConfig.MainMissionConfig, MiscConfig.parseMainMissionConfig, allocator, "resources/MainMission.json");
        const tutorial_guide_cfg = try loadConfig(MiscConfig.TutorialGuideConfig, MiscConfig.parseTutorialGuideConfig, allocator, "resources/TutorialGuideGroup.json");
        const tutorial_cfg = try loadConfig(MiscConfig.TutorialConfig, MiscConfig.parseTutorialConfig, allocator, "resources/TutorialData.json");
        const player_icon_cfg = try loadConfig(MiscConfig.PlayerIconConfig, MiscConfig.parsePlayerIconConfig, allocator, "resources/AvatarPlayerIcon.json");
        const buff_info_cfg = try loadConfig(MiscConfig.TextMapConfig, MiscConfig.parseTextMapConfig, allocator, "resources/BuffInfoConfig.json");
        return .{
            .allocator = allocator,
            .game_config = game_cfg,
            .res_config = res_cfg,
            .map_entrance_config = map_entr_cfg,
            .maze_config = maze_cfg,
            .stage_config = stage_cfg,
            .anchor_config = anchor_cfg,
            .quest_config = quest_cfg,
            .challenge_maze_config = challenge_maze_cfg,
            .challenge_peak_config = challenge_peak_cfg,
            .challenge_peak_group_config = challenge_peak_group_cfg,
            .challenge_peak_boss_config = challenge_peak_boss_cfg,
            .activity_config = activity_cfg,
            .main_mission_config = main_mission_cfg,
            .tutorial_guide_config = tutorial_guide_cfg,
            .tutorial_config = tutorial_cfg,
            .player_icon_config = player_icon_cfg,
            .buff_info_config = buff_info_cfg,
        };
    }
    pub fn deinit(self: *GameConfigCache) void {
        self.game_config.deinit();
        self.res_config.deinit();
        self.map_entrance_config.deinit();
        self.maze_config.deinit();
        self.stage_config.deinit();
        self.anchor_config.deinit();
        self.quest_config.deinit();
        self.challenge_maze_config.deinit();
        self.challenge_peak_config.deinit();
        self.challenge_peak_group_config.deinit();
        self.challenge_peak_boss_config.deinit();
        self.activity_config.deinit();
        self.main_mission_config.deinit();
        self.tutorial_guide_config.deinit();
        self.tutorial_config.deinit();
        self.player_icon_config.deinit();
        self.buff_info_config.deinit(global_main_allocator);
    }
};
pub var global_game_config_cache: GameConfigCache = undefined;
pub var global_main_allocator: Allocator = undefined;
pub fn initGameGlobals(main_allocator: Allocator) !void {
    global_main_allocator = main_allocator;
    global_game_config_cache = try GameConfigCache.init(main_allocator);
}
pub fn deinitGameGlobals() void {
    global_game_config_cache.deinit();
}
var game_config_mtime: i128 = 0;
pub fn UpdateGameConfig() !void {
    const stat = try std.fs.cwd().statFile("config.json");
    if (stat.mtime > game_config_mtime) {
        global_game_config_cache.game_config.deinit();
        global_game_config_cache.game_config = try loadConfig(GameConfig.GameConfig, GameConfig.parseConfig, global_main_allocator, "config.json");
        game_config_mtime = stat.mtime;
    }
}
pub fn loadConfig(
    comptime ConfigType: type,
    comptime parseFn: fn (std.json.Value, Allocator) anyerror!ConfigType,
    allocator: Allocator,
    filename: []const u8,
) anyerror!ConfigType {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var json_tree = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
    defer json_tree.deinit();

    const root = json_tree.value;
    return try parseFn(root, allocator);
}
