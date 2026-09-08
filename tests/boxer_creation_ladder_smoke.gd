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
    _test_ladder_title_fights_and_world_gate()
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

func _test_ladder_title_fights_and_world_gate() -> void:
    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "title ladder fixture has no opponents")
    if opponents.is_empty():
        return

    game_state.new_career("Ladder Boxer", "workhorse")
    _check(str(game_state.career_ladder_stage().get("label", "")) == "동네 신인", "career did not start as a local rookie")
    _check(game_state.ladder_titles().is_empty(), "new career started with a ladder title")

    _set_record(2, 2, 18)
    var district: Dictionary = _offered_title(opponents, "district")
    _check(not district.is_empty(), "district title fight did not unlock at 2 fights / 2 wins")
    _win_title(district)
    _check("district" in game_state.ladder_titles(), "district belt was not recorded after an actual win")
    _check(str(game_state.career_ladder_stage().get("label", "")) == "구·시 챔피언", "district title win did not change career status")
    _check(not bool(game_state.state.career.get("finished", false)), "district title incorrectly ended the career")

    _set_record(5, 4, 35)
    var regional: Dictionary = _offered_title(opponents, "regional")
    _check(not regional.is_empty(), "regional title fight did not unlock after district title")
    _win_title(regional)
    _check("regional" in game_state.ladder_titles(), "regional belt was not recorded after an actual win")
    _check(str(game_state.career_ladder_stage().get("label", "")) == "지역 챔피언", "regional title win did not change career status")

    _set_record(8, 6, 55)
    var national: Dictionary = _offered_title(opponents, "national")
    _check(not national.is_empty(), "national title fight did not unlock after regional title")
    _win_title(national)
    _check("national" in game_state.ladder_titles(), "national belt was not recorded after an actual win")
    _check(str(game_state.career_ladder_stage().get("label", "")) == "대한민국 챔피언", "national title win did not change career status")

    _set_record(11, 8, 72)
    var continental: Dictionary = _offered_title(opponents, "continental")
    _check(not continental.is_empty(), "continental title fight did not unlock after national title")
    _win_title(continental)
    _check("continental" in game_state.ladder_titles(), "continental belt was not recorded after an actual win")
    _check(str(game_state.career_ladder_stage().get("label", "")) == "아시아 챔피언", "continental title win did not change career status")

    _set_record(14, 10, 84)
    _check(str(game_state.career_ladder_stage().get("label", "")) == "세계 랭커", "continental champion did not become world-ranked at the record gate")
    var eliminator: Dictionary = _offered_title(opponents, "world_eliminator")
    _check(not eliminator.is_empty(), "world title eliminator did not unlock at 14 fights / 10 wins")
    _win_title(eliminator)
    _check("world_eliminator" in game_state.ladder_titles(), "world eliminator win was not recorded")
    _check(str(game_state.career_ladder_stage().get("label", "")) == "세계 타이틀 도전자", "eliminator win did not grant contender status")
    _check(not bool(game_state.state.career.get("finished", false)), "world eliminator incorrectly ended the career")

    _set_record(15, 11, 100)
    _check(not game_state.world_title_ready(), "world title unlocked before minimum career length")
    _check(_offered_title(opponents, "world").is_empty(), "world champion appeared before 16 fights / 12 wins")

    _set_record(16, 12, 100)
    _check(game_state.world_title_ready(), "world title did not unlock after eliminator plus 16 fights / 12 wins")
    var world_title: Dictionary = _offered_title(opponents, "world")
    _check(not world_title.is_empty(), "world champion did not appear after all career gates")

func _set_record(fights: int, wins: int, points: int) -> void:
    game_state.state.career.fights = fights
    game_state.state.career.wins = wins
    game_state.state.career.career_points = points
    game_state._sync_progression()

func _offered_title(opponents: Array, title_kind: String) -> Dictionary:
    for value in game_state.get_fight_offers(opponents):
        var opponent: Dictionary = value
        if str(opponent.get("title_kind", "")) == title_kind:
            return opponent
    return {}

func _win_title(opponent: Dictionary) -> void:
    if opponent.is_empty():
        return
    game_state.state.phase = "fight"
    game_state.state.last_weigh_in = {"purse_multiplier": 1.0}
    game_state.apply_fight_result("WIN_DEC", opponent, {"player_hp": 90.0, "opponent_hp": 45.0})

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
