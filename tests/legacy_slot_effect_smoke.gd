extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v12.gd")
const Legacy = preload("res://scripts/core/legacy_service.gd")
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

    _test_stacking_rules()
    _test_training_growth_applies_to_runtime()
    _test_cycle_recovery_applies_to_runtime()
    _test_early_fight_fatigue_applies_to_runtime()
    _test_full_slot_replace()
    _test_full_slot_abandon()
    _finish()

func _test_stacking_rules() -> void:
    _fresh_runtime(2)
    game_state.state.meta_state.legacy_slots = [
        _instance("recovery_routine", 1),
        _instance("recovery_routine", 1),
        _instance("recovery_routine", 1),
    ]
    _check(is_equal_approx(Legacy.effect_value(game_state.state, "cycle_recovery_bonus"), 8.0), "capped recovery stacking must stop at definition cap")

    game_state.state.meta_state.legacy_slots = [
        _instance("fundamentals_handbook", 1),
        _instance("fundamentals_handbook", 1),
        _instance("fundamentals_handbook", 1),
    ]
    _check(is_equal_approx(Legacy.effect_value(game_state.state, "early_camp_growth_percent", {"camp_index": 0}), 17.5), "diminishing stacking must use 1.0/0.5/0.25 scaling")
    _check(is_equal_approx(Legacy.effect_value(game_state.state, "early_camp_growth_percent", {"camp_index": 3}), 0.0), "early camp legacy exceeded its camp limit")

    game_state.state.meta_state.legacy_slots = [
        _instance("precise_jab", 1),
        _instance("precise_jab", 1),
    ]
    _check(is_equal_approx(Legacy.effect_value(game_state.state, "training_technique_bonus"), 2.0), "additive technique stacking mismatch")
    _check(is_equal_approx(Legacy.effect_value(game_state.state, "jab_training_bonus"), 2.0), "additive jab stacking mismatch")

func _test_training_growth_applies_to_runtime() -> void:
    _fresh_runtime(2)
    game_state.state.meta_state.legacy_slots = [_instance("precise_jab", 1)]
    game_state.state.phase = "camp"
    game_state.state.career.money = 999999
    var mitts := _action_by_id("mitts")
    _check(not mitts.is_empty(), "mitts fixture missing")
    if mitts.is_empty():
        return
    var technique_before := int(game_state.state.boxer.technique)
    var result: Dictionary = game_state.apply_camp_action(mitts)
    _check(bool(result.get("ok", false)), "legacy training fixture could not apply camp action")
    _check(int(game_state.state.boxer.technique) - technique_before == 5, "precise jab legacy did not add two real technique points on mitts")
    _check(int(result.get("legacy_growth_bonus", {}).get("technique", 0)) == 2, "camp result did not expose applied legacy growth")

func _test_cycle_recovery_applies_to_runtime() -> void:
    _fresh_runtime(2)
    game_state.state.meta_state.legacy_slots = [
        _instance("recovery_routine", 1),
        _instance("recovery_routine", 1),
        _instance("recovery_routine", 1),
    ]
    game_state.state.boxer.fatigue = 60
    game_state.state.phase = "result"
    var trait_recovery := int(game_state.state.boxer.modifiers.get("recovery_bonus", 0))
    game_state._begin_next_cycle()
    var expected: int = max(0, 60 - 12 - trait_recovery - 8)
    _check(int(game_state.state.boxer.fatigue) == expected, "capped legacy recovery was not applied after base recovery")
    _check(int(game_state.state.career_state.get("last_legacy_cycle_recovery", 0)) == 8, "runtime did not expose legacy recovery feedback")

func _test_early_fight_fatigue_applies_to_runtime() -> void:
    _fresh_runtime(2)
    game_state.state.meta_state.legacy_slots = [_instance("calm_debut", 1)]
    var opponents := _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "opponent fixture missing for legacy fight test")
    if opponents.is_empty():
        return
    game_state.state.phase = "fight"
    game_state.state.boxer.fatigue = 0
    game_state.state.last_weigh_in = {"purse_multiplier": 1.0}
    game_state.apply_fight_result("WIN_DEC", opponents[0], {"player_hp": 100.0, "opponent_hp": 50.0})
    _check(int(game_state.state.boxer.fatigue) == 12, "calm debut did not reduce first-fight fatigue from 14 to 12")
    _check(int(game_state.state.career_state.get("last_legacy_fight_fatigue_reduction", 0)) == 2, "runtime did not expose early-fight legacy reduction")
    _check(Legacy.early_fight_fatigue_reduction(game_state.state, 3) == 0, "early-fight legacy exceeded its fight limit")

func _test_full_slot_replace() -> void:
    _fresh_runtime(4)
    game_state.state.meta_state.legacy_slots = [
        _instance("fundamentals_handbook", 1, "GEN1"),
        _instance("recovery_routine", 2, "GEN2"),
        _instance("calm_debut", 3, "GEN3"),
    ]
    game_state.state.meta_state.lineage_history = [
        {"generation": 1, "boxer_name": "GEN1", "legacy_definition_id": "fundamentals_handbook", "legacy_status": "active", "legacy_active": true},
        {"generation": 2, "boxer_name": "GEN2", "legacy_definition_id": "recovery_routine", "legacy_status": "active", "legacy_active": true},
        {"generation": 3, "boxer_name": "GEN3", "legacy_definition_id": "calm_debut", "legacy_status": "active", "legacy_active": true},
    ]
    _retire_as_early_pro("GEN4")
    var candidates: Array = game_state.retirement_legacy_candidates()
    _check(not candidates.is_empty(), "full-slot fixture has no candidates")
    if candidates.is_empty():
        return

    var pending_result: Dictionary = game_state.select_retirement_legacy(str(candidates[0].id))
    _check(bool(pending_result.get("ok", false)), "full-slot legacy selection should enter slot-decision state")
    _check(bool(pending_result.get("requires_slot_decision", false)), "full-slot selection did not require replace/abandon decision")
    _check(game_state.state.meta_state.legacy_slots.size() == 3, "pending full-slot selection changed active slots early")
    _check(not game_state.pending_retirement_legacy().is_empty(), "pending legacy was not persisted")

    var blocked: Dictionary = game_state.select_retirement_legacy(str(candidates[min(1, candidates.size() - 1)].id))
    _check(str(blocked.get("reason", "")) == "slot_decision_pending", "player could change legacy candidate after full-slot commitment")

    var old_slot: Dictionary = game_state.state.meta_state.legacy_slots[1].duplicate(true)
    var replaced: Dictionary = game_state.replace_retirement_legacy(1)
    _check(bool(replaced.get("ok", false)), "full-slot replacement failed")
    _check(game_state.state.meta_state.legacy_slots.size() == 3, "replacement changed slot count")
    _check(int(game_state.state.meta_state.legacy_slots[1].source_generation) == 4, "replacement slot did not receive current generation legacy")
    _check(str(game_state.state.career_state.retirement_legacy_selected.get("legacy_status", "")) == "active", "replacement did not finalize current career legacy")
    _check(game_state.pending_retirement_legacy().is_empty(), "pending legacy survived replacement")

    var replaced_history := false
    for value in game_state.state.meta_state.lineage_history:
        var history: Dictionary = value
        if int(history.get("generation", 0)) == int(old_slot.get("source_generation", 0)):
            replaced_history = str(history.get("legacy_status", "")) == "replaced" and not bool(history.get("legacy_active", true))
    _check(replaced_history, "replaced legacy remained active in lineage history")

func _test_full_slot_abandon() -> void:
    _fresh_runtime(5)
    game_state.state.meta_state.legacy_slots = [
        _instance("fundamentals_handbook", 1, "GEN1"),
        _instance("recovery_routine", 2, "GEN2"),
        _instance("calm_debut", 3, "GEN3"),
    ]
    _retire_as_early_pro("GEN5")
    var candidates: Array = game_state.retirement_legacy_candidates()
    _check(not candidates.is_empty(), "abandon fixture has no candidates")
    if candidates.is_empty():
        return
    var before_slots: Array = game_state.state.meta_state.legacy_slots.duplicate(true)
    var pending_result: Dictionary = game_state.select_retirement_legacy(str(candidates[0].id))
    _check(bool(pending_result.get("requires_slot_decision", false)), "abandon fixture did not enter slot decision")
    var abandoned: Dictionary = game_state.abandon_retirement_legacy()
    _check(bool(abandoned.get("ok", false)), "abandoning new legacy failed")
    _check(str(game_state.state.career_state.retirement_legacy_selected.get("legacy_status", "")) == "abandoned", "abandoned legacy was not finalized as the career's one choice")
    _check(game_state.state.meta_state.legacy_slots == before_slots, "abandoning new legacy changed active slots")

    var advanced: Dictionary = game_state.start_next_generation()
    _check(bool(advanced.get("ok", false)), "next generation could not start after abandoning full-slot legacy")
    _check(int(game_state.state.meta_state.get("generation", 0)) == 6, "generation did not advance after abandon decision")
    var history: Array = game_state.state.meta_state.get("lineage_history", [])
    _check(not history.is_empty(), "abandoned legacy career was not archived")
    if not history.is_empty():
        var latest: Dictionary = history[-1]
        _check(str(latest.get("legacy_status", "")) == "abandoned", "lineage history lost abandoned legacy status")
        _check(not bool(latest.get("legacy_active", true)), "abandoned legacy was marked active in lineage history")

func _fresh_runtime(generation: int) -> void:
    game_state.new_career("TEST BOXER", "technician")
    game_state.state["meta_state"] = {
        "generation": generation,
        "legacy_capacity": 3,
        "legacy_slots": [],
        "achievements": [],
        "lineage_history": [],
    }
    game_state.state["world_state"] = {"world_date": {"year": 2030 + generation}}
    game_state.state["career_state"] = {
        "career_high_points": int(game_state.state.career.get("career_points", 0)),
        "career_high_rank": int(game_state.state.career.get("rank", 50)),
        "career_high_tier": str(game_state.state.career.get("tier", "prospect")),
    }
    Save.save_game(game_state.state)

func _retire_as_early_pro(boxer_name: String) -> void:
    game_state.state.boxer.name = boxer_name
    game_state.state.career.career_points = 10
    game_state._sync_progression()
    game_state.state.career.finished = true
    game_state.state.career.ending = "loss_retirement"
    game_state.state.phase = "career_summary"
    Save.save_game(game_state.state)

func _instance(definition_id: String, generation: int, boxer_name: String = "SOURCE") -> Dictionary:
    return {
        "definition_id": definition_id,
        "source_boxer_name": boxer_name,
        "source_generation": generation,
        "source_retirement_year": 2030 + generation,
        "source_ending": "loss_retirement",
        "source_legacy_tier": "early_pro",
        "source_flavor": "테스트",
        "legacy_status": "active",
    }

func _action_by_id(action_id: String) -> Dictionary:
    for value in _load_array("res://data/camp_actions.json"):
        var action: Dictionary = value
        if str(action.get("id", "")) == action_id:
            return action
    return {}

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _finish() -> void:
    if is_instance_valid(game_state):
        game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("legacy-slot-effect-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
