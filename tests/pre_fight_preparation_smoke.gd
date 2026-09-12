extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v12.gd")
const Save = preload("res://scripts/core/save_service.gd")
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

var failures: Array[String] = []
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    game_state = StateScript.new()
    get_root().add_child(game_state)
    await process_frame

    var opponents: Array = _load_array("res://data/opponents.json")
    var camp_actions: Array = _load_array("res://data/camp_actions.json")
    _check(not opponents.is_empty(), "preparation smoke has no opponent fixture")
    _check(not camp_actions.is_empty(), "preparation smoke has no camp fixture")
    if opponents.is_empty() or camp_actions.is_empty():
        _finish()
        return

    game_state.new_career("Prep Boxer", "technician")
    game_state.state.career.money = 999999
    var raw_before := _trainable_snapshot(game_state.state.boxer)
    var mitts: Dictionary = _action_by_id(camp_actions, "mitts").duplicate(true)
    # This smoke isolates preparation composition. Random training injuries are
    # covered elsewhere and can apply shoulder_strain (-3 speed), which makes
    # the temporary +6 speed assertion nondeterministic without changing prep.
    mitts["risk"] = 0.0
    var camp_result: Dictionary = game_state.apply_camp_action(mitts)
    _check(bool(camp_result.get("ok", false)), "development camp action failed")
    _check(str(game_state.state.phase) == "fight_offer", "development did not end at fight offers")
    _check(int(game_state.state.boxer.speed) - int(raw_before.speed) == 3, "mitts speed growth changed from the intended single development gain")
    _check(int(game_state.state.boxer.technique) - int(raw_before.technique) >= 3, "mitts technique growth regressed")

    var developed := _trainable_snapshot(game_state.state.boxer)
    game_state.select_opponent(opponents[0])
    _check(str(game_state.state.phase) == "tactical_prep", "opponent selection did not enter tactical preparation")

    var tactical_result: Dictionary = game_state.select_tactical_preparation("distance_drill")
    _check(bool(tactical_result.get("ok", false)), "distance tactical preparation failed")
    _check(str(game_state.state.phase) == "condition_prep", "tactical preparation did not enter condition preparation")
    _check(_trainable_snapshot(game_state.state.boxer) == developed, "tactical preparation changed permanent boxer stats")

    game_state.state.boxer.fatigue = 40
    game_state.state.boxer.health = 90
    game_state.state.boxer.weight_kg = 65.0
    var condition_before := {
        "fatigue": int(game_state.state.boxer.fatigue),
        "health": int(game_state.state.boxer.health),
        "weight_kg": float(game_state.state.boxer.weight_kg)
    }
    var rest_result: Dictionary = game_state.select_condition_preparation("full_rest")
    _check(bool(rest_result.get("ok", false)), "rest condition preparation failed")
    _check(str(game_state.state.phase) == "game_plan", "condition preparation did not enter game plan")
    _check(int(game_state.state.boxer.fatigue) == 28, "rest condition did not recover fatigue")
    _check(int(game_state.state.boxer.health) == 92, "rest condition did not recover health")
    _check(_trainable_snapshot(game_state.state.boxer) == developed, "condition preparation granted permanent trainable stats")

    var rollback: Dictionary = game_state.return_to_condition_preparation()
    _check(bool(rollback.get("ok", false)), "condition preparation rollback failed")
    _check(str(game_state.state.phase) == "condition_prep", "condition rollback did not return to condition phase")
    _check(int(game_state.state.boxer.fatigue) == int(condition_before.fatigue), "condition rollback stacked or lost fatigue")
    _check(int(game_state.state.boxer.health) == int(condition_before.health), "condition rollback stacked or lost health")
    _check(is_equal_approx(float(game_state.state.boxer.weight_kg), float(condition_before.weight_kg)), "condition rollback stacked or lost weight")

    var sharp_result: Dictionary = game_state.select_condition_preparation("sharpness")
    _check(bool(sharp_result.get("ok", false)), "sharpness condition preparation failed")
    var raw_after_sharp := _trainable_snapshot(game_state.state.boxer)
    _check(raw_after_sharp == developed, "sharpness leaked temporary stats into permanent boxer growth")

    var plan_result: Dictionary = game_state.select_game_plan("outside_boxing")
    _check(bool(plan_result.get("ok", false)), "game plan failed after preparation")
    _check(str(game_state.state.phase) == "fight", "game plan did not advance to fight")

    var fight_boxer: Dictionary = game_state.get_fight_boxer()
    _check(int(fight_boxer.speed) >= int(game_state.state.boxer.speed) + 6, "condition + game-plan temporary speed did not reach fight boxer")
    var action_modifiers: Dictionary = fight_boxer.get("game_plan", {}).get("action_modifiers", {})
    var jab_mods: Dictionary = action_modifiers.get("jab", {})
    _check(int(jab_mods.get("speed", 0)) >= 13, "distance preparation did not combine with outside-boxing jab speed")
    _check(int(jab_mods.get("technique", 0)) >= 14, "distance preparation did not combine with outside-boxing jab technique")
    _check(_trainable_snapshot(game_state.state.boxer) == developed, "fight preparation permanently inflated boxer stats")

    _finish()

func _trainable_snapshot(boxer: Dictionary) -> Dictionary:
    var out := {}
    for stat in TRAINABLE_STATS:
        out[stat] = int(boxer.get(stat, 0))
    return out

func _action_by_id(actions: Array, action_id: String) -> Dictionary:
    for value in actions:
        var action: Dictionary = value
        if str(action.get("id", "")) == action_id:
            return action
    return {}

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
        print("pre-fight-preparation-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
