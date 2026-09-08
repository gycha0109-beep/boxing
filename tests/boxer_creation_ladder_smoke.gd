extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v14.gd")
const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    game_state = StateScript.new()
    get_root().add_child(game_state)
    await process_frame

    _test_style_choice_and_talent_separation()
    _test_stat_help_contract()
    _test_world_title_gate()
    _test_ladder_progression()
    _finish()

func _test_style_choice_and_talent_separation() -> void:
    game_state.new_career("Build Boxer", "glass_cannon")
    game_state.begin_boxer_creation()
    _check(str(game_state.state.phase) == "style_select", "new boxer creation did not enter style selection")
    _check(str(game_state.state.boxer.get("trait_id", "")) == "glass_cannon", "creation changed predetermined natural talent")

    var selected: Dictionary = game_state.select_boxing_style("out_boxer")
    _check(bool(selected.get("ok", false)), "out-boxer style selection failed")
    _check(str(game_state.state.phase) == "talent_reveal", "style selection did not enter talent reveal")
    _check(str(game_state.state.boxer.get("identity_id", "")) == "out_boxer", "chosen boxing style was not stored")
    _check(str(game_state.state.boxer.get("trait_id", "")) == "glass_cannon", "style selection overwrote natural talent")

    # Base 50 + glass-cannon talent + chosen out-boxer style.
    _check(int(game_state.state.boxer.power) == 55, "style/talent power composition mismatch")
    _check(int(game_state.state.boxer.speed) == 54, "style/talent speed composition mismatch")
    _check(int(game_state.state.boxer.technique) == 53, "style/talent technique composition mismatch")
    _check(int(game_state.state.boxer.defense) == 47, "style/talent defense composition mismatch")

    var talent: Dictionary = game_state.talent_definition()
    _check(str(talent.get("name", "")) == "유리 대포", "natural talent definition lookup failed")
    var confirmed: Dictionary = game_state.confirm_talent()
    _check(bool(confirmed.get("ok", false)), "talent confirmation failed")
    _check(str(game_state.state.phase) == "camp", "talent confirmation did not enter camp")
    _check(bool(game_state.state.get("boxer_creation_complete", false)), "boxer creation completion was not persisted")

func _test_stat_help_contract() -> void:
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        _check(not str(game_state.stat_help(stat)).is_empty(), "missing player-facing stat help: %s" % stat)

func _test_world_title_gate() -> void:
    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "title gate fixture has no opponents")
    if opponents.is_empty():
        return

    game_state.new_career("Gate Boxer", "technician")
    game_state.state.career.career_points = 100
    game_state.state.career.fights = 10
    game_state.state.career.wins = 10
    game_state._sync_progression()
    _check(not game_state.world_title_ready(), "world title became ready before minimum career length")
    var early_offers: Array = game_state.get_fight_offers(opponents)
    for value in early_offers:
        var opponent: Dictionary = value
        _check(not bool(opponent.get("title_fight", false)), "world title opponent appeared before 16 fights / 12 wins")

    game_state.state.career.fights = 16
    game_state.state.career.wins = 12
    game_state.state.career.career_points = 100
    game_state._sync_progression()
    _check(game_state.world_title_ready(), "world title did not unlock at minimum gate")
    var late_offers: Array = game_state.get_fight_offers(opponents)
    var found_title := false
    for value in late_offers:
        var opponent: Dictionary = value
        if bool(opponent.get("title_fight", false)):
            found_title = true
    _check(found_title, "world title opponent did not appear after gate was satisfied")

func _test_ladder_progression() -> void:
    game_state.new_career("Ladder Boxer", "workhorse")
    var stage: Dictionary = game_state.career_ladder_stage()
    _check(str(stage.get("label", "")) == "동네 신인", "career did not start at local rookie stage")

    game_state.state.career.fights = 3
    game_state.state.career.wins = 2
    stage = game_state.career_ladder_stage()
    _check(str(stage.get("label", "")) == "구·시 챔피언", "district title stage did not unlock")

    game_state.state.career.fights = 9
    game_state.state.career.wins = 6
    stage = game_state.career_ladder_stage()
    _check(str(stage.get("label", "")) == "대한민국 챔피언", "national title stage did not unlock")

    game_state.state.career.fights = 14
    game_state.state.career.wins = 10
    stage = game_state.career_ladder_stage()
    _check(str(stage.get("label", "")) == "세계 랭커", "world-ranked stage did not unlock")

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(game_state):
        game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("boxer-creation-ladder-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
