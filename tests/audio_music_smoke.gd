extends SceneTree

const Director = preload("res://scripts/ui/music_director.gd")

var failures: Array[String] = []
var director: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_phase_routing()
    _test_track_contrast()

    director = Director.new()
    get_root().add_child(director)
    await process_frame

    director.set_mode("career")
    _check(str(director.current_mode) == "career", "career BGM mode did not activate")
    _check(int(director.mode_switch_count) == 1, "music mode switch was not tracked")

    director.set_mode("fight")
    _check(str(director.current_mode) == "fight", "fight BGM mode did not activate")
    _check(int(director.mode_switch_count) == 2, "fight music mode switch was not tracked")

    director.play_ui("purchase")
    _check(str(director.last_ui_cue) == "purchase", "purchase UI cue did not route")
    _check(int(director.ui_cue_count) == 1, "UI cue count did not advance")

    director.duck(0.52)
    _check(float(director.duck_gain) < 0.55, "impact ducking did not lower BGM gain")

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

func _finish() -> void:
    if is_instance_valid(director):
        director.queue_free()
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
