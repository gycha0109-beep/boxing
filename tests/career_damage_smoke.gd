extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v16.gd")
const Save = preload("res://scripts/core/save_service.gd")
const Risk = preload("res://scripts/core/career_risk_service.gd")

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
    _test_brutal_ko_creates_chronic_damage()
    _test_milestone_is_applied_only_once()
    _test_damage_persists_and_forces_retirement()
    _test_next_generation_resets_current_career_damage()
    _finish()

func _test_brutal_ko_creates_chronic_damage() -> void:
    _check(game_state.career_damage_value() == 0, "new career must start with zero career damage")
    _check(game_state.chronic_injuries().is_empty(), "new career must start without chronic injuries")
    var power_before: int = int(game_state.state.boxer.power)
    var technique_before: int = int(game_state.state.boxer.technique)
    game_state.state.boxer.fatigue = 80
    game_state.state.phase = "fight"
    game_state.apply_fight_result("LOSS_KO", opponents[0], {"player_hp": 0.0, "opponent_hp": 64.0})
    _check(game_state.career_damage_value() >= 25, "brutal KO should cross the first chronic-damage milestone")
    _check(game_state.chronic_injuries().size() == 1, "first chronic milestone did not create exactly one chronic injury")
    _check(str(game_state.chronic_injuries()[0].get("id", "")) == "chronic_hands", "unexpected first chronic injury")
    _check(int(game_state.state.boxer.power) == power_before - 1, "chronic hands did not apply permanent power loss")
    _check(int(game_state.state.boxer.technique) == technique_before - 1, "chronic hands did not apply permanent technique loss")
    _check(game_state.career_health_ceiling() == 97, "first chronic milestone did not reduce max health")
    game_state.state.boxer.health = 100
    Risk.ensure_state(game_state.state)
    _check(int(game_state.state.boxer.health) == 97, "health ceiling is not enforced")

func _test_milestone_is_applied_only_once() -> void:
    var power_after_first: int = int(game_state.state.boxer.power)
    var technique_after_first: int = int(game_state.state.boxer.technique)
    game_state.state.phase = "fight"
    game_state.state.boxer.fatigue = 0
    game_state.apply_fight_result("WIN_DEC", opponents[0], {"player_hp": 100.0, "opponent_hp": 20.0})
    _check(game_state.chronic_injuries().size() == 1, "same damage milestone created duplicate chronic injuries")
    _check(int(game_state.state.boxer.power) == power_after_first, "first milestone power penalty was applied twice")
    _check(int(game_state.state.boxer.technique) == technique_after_first, "first milestone technique penalty was applied twice")

func _test_damage_persists_and_forces_retirement() -> void:
    var saved_damage: int = game_state.career_damage_value()
    _check(Save.save_game(game_state.state), "career-damage fixture could not save")
    var loaded: Dictionary = Save.load_game()
    _check(int(loaded.get("career_state", {}).get("career_damage", -1)) == saved_damage, "career damage did not survive save round-trip")
    _check(loaded.get("career_state", {}).get("injuries", []).size() == 1, "chronic injury did not survive save round-trip")
    game_state.state.career_state["career_damage"] = 99
    game_state.state.phase = "fight"
    game_state.state.boxer.fatigue = 0
    game_state.state.boxer.health = game_state.career_health_ceiling()
    game_state.apply_fight_result("WIN_DEC", opponents[0], {"player_hp": 100.0, "opponent_hp": 10.0})
    _check(game_state.career_damage_value() >= 100, "career damage did not reach forced-retirement threshold")
    _check(bool(game_state.state.career.finished), "forced retirement did not finish the career")
    _check(str(game_state.state.career.ending) == "career_damage_retirement", "forced retirement ending mismatch")
    _check(game_state.chronic_injuries().size() == 3, "crossing late damage thresholds did not apply all chronic milestones exactly once")

func _test_next_generation_resets_current_career_damage() -> void:
    var candidates: Array = game_state.retirement_legacy_candidates()
    _check(not candidates.is_empty(), "forced-retirement career did not produce Legacy candidates")
    if candidates.is_empty(): return
    var selected: Dictionary = game_state.select_retirement_legacy(str(candidates[0].get("id", "")))
    _check(bool(selected.get("ok", false)), "could not select Legacy after forced retirement")
    var advanced: Dictionary = game_state.start_next_generation()
    _check(bool(advanced.get("ok", false)), "could not start next generation after forced retirement")
    _check(game_state.career_damage_value() == 0, "career damage leaked into the next boxer")
    _check(game_state.chronic_injuries().is_empty(), "chronic injuries leaked into the next boxer")
    _check(game_state.career_health_ceiling() == 100, "next boxer inherited prior health ceiling")

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _finish() -> void:
    if is_instance_valid(game_state): game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("career-damage-smoke: PASS")
        quit(0)
        return
    for failure in failures: push_error(failure)
    quit(1)

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
    if not condition: failures.append(message)
