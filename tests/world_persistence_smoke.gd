extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v16.gd")
const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var game_state: Node
var opponents: Array = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    opponents = _load_array("res://data/opponents.json")
    game_state = StateScript.new()
    get_root().add_child(game_state)
    await process_frame
    _test_initial_world_contract()
    _test_world_advances_by_actual_career_duration()
    _test_champion_retirement_and_successor()
    _test_world_title_offer_uses_persisted_champion()
    _finish()

func _test_initial_world_contract() -> void:
    var world: Dictionary = game_state.state.get("world_state", {})
    _check(int(world.get("world_date", {}).get("year", 0)) == 2030, "world must begin in 2030")
    _check(int(world.get("world_date", {}).get("month", 0)) == 1, "world must begin in January")
    _check(world.get("opponents", []).size() == 17, "world must seed all 17 named opponents")
    _check(str(world.get("champion_boxer_id", "")) == "viktor_kozlov", "Viktor must seed as the initial world champion")
    var champion: Dictionary = _world_snapshot("viktor_kozlov")
    for key in ["name", "age", "style", "gym_id", "record", "rank", "champion", "title_defenses", "career_damage", "career_start_year", "traits"]:
        _check(champion.has(key), "world NPC missing minimum field: %s" % key)

func _test_world_advances_by_actual_career_duration() -> void:
    var champion_before: Dictionary = _world_snapshot("viktor_kozlov")
    var start_age: int = int(game_state.state.career_state.get("career_start_age_months", game_state.state.career.age_months))
    game_state.state.career.age_months = start_age + 84
    game_state.state.career.career_points = 82
    game_state._sync_progression()
    game_state.state.career.finished = true
    game_state.state.career.ending = "loss_retirement"
    Save.save_game(game_state.state)
    _select_first_legacy()
    var advanced: Dictionary = game_state.start_next_generation()
    _check(bool(advanced.get("ok", false)), "generation handoff failed")
    _check(int(advanced.get("world_advanced_months", -1)) == 84, "world must advance by the actual 84-month career")
    _check(int(game_state.state.world_state.world_date.year) == 2037 and int(game_state.state.world_state.world_date.month) == 1, "world date did not advance exactly seven years")
    _check(int(game_state.state.meta_state.get("generation", 0)) == 2, "generation did not increment")
    _check(str(game_state.state.world_state.get("champion_boxer_id", "")) == "viktor_kozlov", "unbeaten champion should persist into the next generation")
    var champion_after: Dictionary = _world_snapshot("viktor_kozlov")
    _check(int(champion_after.get("age", 0)) == int(champion_before.get("age", 0)) + 7, "champion age did not advance with world time")
    _check(int(champion_after.get("title_defenses", 0)) > int(champion_before.get("title_defenses", 0)), "persistent champion did not accumulate title defenses")

func _test_champion_retirement_and_successor() -> void:
    var start_age: int = int(game_state.state.career_state.get("career_start_age_months", game_state.state.career.age_months))
    game_state.state.career.age_months = start_age + 24
    game_state.state.career.career_points = 32
    game_state._sync_progression()
    game_state.state.career.finished = true
    game_state.state.career.ending = "age_retirement"
    Save.save_game(game_state.state)
    _select_first_legacy()
    var advanced: Dictionary = game_state.start_next_generation()
    _check(bool(advanced.get("ok", false)), "second generation handoff failed")
    var viktor: Dictionary = _world_snapshot("viktor_kozlov")
    _check(bool(viktor.get("retired", false)), "38-year-old champion must retire during world update")
    _check(not bool(viktor.get("champion", true)), "retired champion retained the belt")
    _check(str(game_state.state.world_state.get("champion_boxer_id", "")) == "diego_reyes", "world title successor selection should deterministically promote Diego")
    var diego: Dictionary = _world_snapshot("diego_reyes")
    _check(bool(diego.get("champion", false)), "successor was not marked champion")
    _check(_history_has_type("champion_retired"), "world history did not record champion retirement")
    _check(_history_has_type("new_world_champion"), "world history did not record title succession")

func _test_world_title_offer_uses_persisted_champion() -> void:
    game_state.state.career_state["ladder_titles"] = ["district", "regional", "national", "continental", "world_eliminator"]
    game_state.state.career.fights = 16
    game_state.state.career.wins = 12
    game_state.state.career.career_points = 90
    game_state._sync_progression()
    var offers: Array = game_state.get_fight_offers(opponents)
    var found_world_title := false
    for value in offers:
        var opponent: Dictionary = value
        if str(opponent.get("title_kind", "")) != "world":
            continue
        found_world_title = true
        _check(str(opponent.get("id", "")) == "diego_reyes", "world title offer ignored the persisted champion")
        _check(int(opponent.get("age", 0)) >= 37, "persisted champion age missing from decorated offer")
        _check(str(opponent.get("world_age_profile", "")) == "veteran", "older champion did not receive veteran age profile")
    _check(found_world_title, "world-title-ready career did not receive a world title offer")

func _select_first_legacy() -> void:
    var candidates: Array = game_state.retirement_legacy_candidates()
    _check(not candidates.is_empty(), "retirement legacy candidates missing")
    if candidates.is_empty():
        return
    var selected: Dictionary = game_state.select_retirement_legacy(str(candidates[0].get("id", "")))
    _check(bool(selected.get("ok", false)), "retirement legacy selection failed")

func _world_snapshot(opponent_id: String) -> Dictionary:
    for value in game_state.state.get("world_state", {}).get("opponents", []):
        var snapshot: Dictionary = value
        if str(snapshot.get("id", "")) == opponent_id:
            return snapshot
    return {}

func _history_has_type(event_type: String) -> bool:
    for value in game_state.state.get("world_state", {}).get("world_history", []):
        var event: Dictionary = value
        if str(event.get("type", "")) == event_type:
            return true
    return false

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _finish() -> void:
    if is_instance_valid(game_state): game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("world-persistence-smoke: PASS")
        quit(0)
        return
    for failure in failures: push_error(failure)
    quit(1)

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
    if not condition: failures.append(message)
