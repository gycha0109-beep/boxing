extends SceneTree

const Director = preload("res://scripts/ui/music_director.gd")
const Impact = preload("res://scripts/ui/impact_feedback.gd")
const Arena = preload("res://scripts/ui/arena_audio.gd")

var failures: Array[String] = []
var director: Node
var impact: Node
var arena: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_phase_routing()
    _test_track_contrast()
    _test_phone_mix_contract()
    _test_commercial_asset_inventory()

    director = Director.new()
    impact = Impact.new()
    arena = Arena.new()
    get_root().add_child(director)
    get_root().add_child(impact)
    get_root().add_child(arena)
    await process_frame

    director.set_mode("career")
    _check(str(director.current_mode) == "career", "career BGM mode did not activate")
    _check(int(director.mode_switch_count) == 1, "music mode switch was not tracked")
    _check(str(director.last_music_asset_path) == Director.music_asset_path("career"), "career mode did not select the commercial track")
    _check(director.music_player != null and not (director.music_player.stream is AudioStreamGenerator), "career BGM still uses procedural AudioStreamGenerator")

    director.set_mode("fight")
    _check(str(director.current_mode) == "fight", "fight BGM mode did not activate")
    _check(int(director.mode_switch_count) == 2, "fight music mode switch was not tracked")
    _check(str(director.last_music_asset_path) == Director.music_asset_path("fight"), "fight mode did not select the commercial ring track")
    _check(director.music_player != null and not (director.music_player.stream is AudioStreamGenerator), "fight BGM still uses procedural AudioStreamGenerator")

    director.play_ui("purchase")
    _check(str(director.last_ui_cue) == "purchase", "purchase UI cue did not route")
    _check(int(director.ui_cue_count) == 1, "UI cue count did not advance")

    director.duck(0.72)
    _check(float(director.duck_gain) <= 0.30, "impact ducking is not deep enough for punch priority")

    var hit_exchange := {
        "player_action": "jab",
        "opponent_action": "guard",
        "player_event": {"hit": true, "damage": 8.0},
        "opponent_event": {"hit": false, "damage": 0.0},
    }
    impact.trigger(hit_exchange)
    _check(str(impact.last_asset_path).begins_with("res://assets/audio/sfx/punches/jab_"), "jab exchange did not select the recorded jab pool")
    _check(not impact.impact_players.is_empty(), "recorded impact players were not created")
    if not impact.impact_players.is_empty():
        _check(not (impact.impact_players[0].stream is AudioStreamGenerator), "combat impact still uses procedural AudioStreamGenerator")

    var block_exchange := {
        "player_action": "guard",
        "opponent_action": "jab",
        "player_event": {"guard": true, "hit": false, "damage": 0.0},
        "opponent_event": {"guard": false, "hit": false, "damage": 0.0},
    }
    impact.trigger(block_exchange)
    _check(str(impact.last_asset_path).begins_with("res://assets/audio/sfx/blocks/block_"), "guard exchange did not select the recorded block pool")

    arena.start_fight()
    _check(arena.crowd_player != null and arena.crowd_player.stream != null, "fight start did not load recorded crowd ambience")
    _check(arena.crowd_player != null and not (arena.crowd_player.stream is AudioStreamGenerator), "crowd ambience still uses procedural AudioStreamGenerator")
    _check(str(arena.last_cue_asset_path) == Arena.ROUND_BELL_PATH, "fight start did not select the recorded round bell")
    arena.react({
        "player_action": "power",
        "opponent_action": "guard",
        "player_event": {"hit": true, "damage": 18.0},
        "opponent_event": {"hit": false, "damage": 0.0},
    })
    _check(str(arena.last_reaction) == "big_hit", "heavy exchange did not route to a recorded big-hit crowd reaction")
    _check(str(arena.last_reaction_asset_path).begins_with("res://assets/audio/sfx/crowd/reaction_big_hit_"), "heavy crowd reaction did not select the recorded reaction pool")
    arena.finish_fight()
    _check(str(arena.last_cue_asset_path) == Arena.FINAL_BELL_PATH, "fight finish did not select the recorded final bell")

    director.set_suspended(true)
    _check(bool(director.suspended), "music did not suspend with app lifecycle")
    director.set_suspended(false)
    _check(not bool(director.suspended), "music did not resume with app lifecycle")

    _finish()

func _test_phase_routing() -> void:
    _check(Director.mode_for_phase("", true) == "menu", "launch title should use menu music")
    _check(Director.mode_for_phase("camp") == "career", "camp should use career music")
    _check(Director.mode_for_phase("equipment_shop") == "career", "equipment shop should use career music")
    _check(Director.mode_for_phase("fight_offer") == "fight_week", "fight offer should build tension")
    _check(Director.mode_for_phase("tactical_prep") == "fight_week", "tactical prep should use fight-week music")
    _check(Director.mode_for_phase("game_plan") == "fight_week", "game plan should use fight-week music")
    _check(Director.mode_for_phase("fight") == "fight", "live fight should use fight music")
    _check(Director.mode_for_phase("career_summary") == "legacy", "career summary should use legacy music")

func _test_track_contrast() -> void:
    var menu: Dictionary = Director.track_profile("menu")
    var fight: Dictionary = Director.track_profile("fight")
    var legacy: Dictionary = Director.track_profile("legacy")
    _check(float(fight.get("bpm", 0.0)) > float(menu.get("bpm", 0.0)), "fight BGM is not faster than menu BGM")
    _check(float(fight.get("intensity", 0.0)) > float(menu.get("intensity", 0.0)), "fight BGM is not more intense than menu BGM")
    _check(float(legacy.get("pad", 0.0)) > float(fight.get("pad", 0.0)), "legacy BGM should be more spacious than fight BGM")

func _test_phone_mix_contract() -> void:
    _check(float(Director.MUSIC_VOLUME_DB) <= -18.0, "BGM must stay behind combat audio on phone speakers")
    _check(float(Director.UI_VOLUME_DB) <= -12.0, "UI cues are too loud relative to punch audio")
    _check(float(Arena.CROWD_VOLUME_DB) <= -16.0, "crowd ambience is too loud relative to impact audio")

    var glove_hit: Dictionary = Impact.impact_profile("medium", "glove_head_hit")
    var heavy_hit: Dictionary = Impact.impact_profile("heavy", "head_crack")
    var body_hit: Dictionary = Impact.impact_profile("medium", "body_hit")
    _check(float(glove_hit.get("body_frequency", 0.0)) >= 160.0, "normal punch body tone is below reliable phone-speaker range")
    _check(float(glove_hit.get("crack_frequency", 0.0)) >= 500.0, "normal punch lacks an audible midrange transient")
    _check(float(heavy_hit.get("crack_frequency", 0.0)) >= 800.0, "heavy punch lacks a distinct crack transient")
    _check(float(body_hit.get("crack_frequency", 0.0)) >= 320.0, "body punch lacks phone-audible attack")
    _check(float(heavy_hit.get("amplitude", 0.0)) > float(glove_hit.get("amplitude", 0.0)), "heavy punch should hit harder than normal punch")

func _test_commercial_asset_inventory() -> void:
    for mode_id in ["menu", "career", "fight_week", "fight", "legacy"]:
        var path := Director.music_asset_path(mode_id)
        _check(not path.is_empty() and ResourceLoader.exists(path), "missing commercial BGM asset for %s: %s" % [mode_id, path])
    for path in Impact.JAB_ASSETS + Impact.HEAD_ASSETS + Impact.HEAVY_ASSETS + Impact.COUNTER_ASSETS + Impact.BODY_ASSETS + Impact.BLOCK_ASSETS + Impact.SWING_ASSETS:
        _check(ResourceLoader.exists(str(path)), "missing commercial combat asset: %s" % str(path))
    for path in Impact.LIGHT_VOICE_ASSETS + Impact.HEAVY_VOICE_ASSETS + Impact.BODY_VOICE_ASSETS + Impact.KNOCKDOWN_VOICE_ASSETS:
        _check(ResourceLoader.exists(str(path)), "missing commercial voice asset: %s" % str(path))
    _check(ResourceLoader.exists(Arena.CROWD_AMBIENCE_PATH), "missing recorded crowd ambience")
    _check(ResourceLoader.exists(Arena.ROUND_BELL_PATH), "missing recorded round bell")
    _check(ResourceLoader.exists(Arena.FINAL_BELL_PATH), "missing recorded final bell")
    for path in Arena.SMALL_REACTIONS + Arena.BIG_HIT_REACTIONS + Arena.KNOCKDOWN_REACTIONS + Arena.WIN_REACTIONS:
        _check(ResourceLoader.exists(str(path)), "missing commercial crowd reaction: %s" % str(path))

func _finish() -> void:
    if is_instance_valid(director):
        director.queue_free()
    if is_instance_valid(impact):
        impact.queue_free()
    if is_instance_valid(arena):
        arena.queue_free()
    if failures.is_empty():
        print("audio-music-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
