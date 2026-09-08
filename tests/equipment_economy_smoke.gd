extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v15.gd")
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

    _test_low_base_and_zero_sum_styles()
    _test_personal_equipment_spends_money_and_adds_stats()
    _test_title_locked_upgrades()
    _test_gym_equipment_improves_training_over_time()
    _test_new_career_resets_equipment()
    _finish()

func _test_low_base_and_zero_sum_styles() -> void:
    game_state.new_career("Economy Boxer", "glass_cannon")
    game_state.begin_boxer_creation()
    var selected: Dictionary = game_state.select_boxing_style("balanced")
    _check(bool(selected.get("ok", false)), "balanced style selection failed")
    _check(int(game_state.state.boxer.power) == 47, "base 40 + glass-cannon power composition mismatch")
    _check(int(game_state.state.boxer.speed) == 40, "balanced style should not alter speed")
    _check(int(game_state.state.boxer.technique) == 40, "balanced style should not alter technique")
    _check(int(game_state.state.boxer.defense) == 37, "base 40 + glass-cannon defense composition mismatch")
    _check(int(game_state.state.boxer.conditioning) == 40, "balanced style should not alter conditioning")

    for value in game_state.boxing_styles():
        var style: Dictionary = value
        var total := 0
        for stat in game_state.TRAINABLE_STATS:
            total += int(style.get("stat_bonus", {}).get(stat, 0))
        _check(total == 0, "boxing style is not zero-sum: %s total=%d" % [str(style.get("id", "")), total])

func _test_personal_equipment_spends_money_and_adds_stats() -> void:
    game_state.new_career("Gear Boxer", "workhorse")
    game_state.state.phase = "camp"
    var before_money := int(game_state.state.career.money)
    var before_power := int(game_state.state.boxer.power)
    var bought: Dictionary = game_state.purchase_equipment("personal", "club_gloves")
    _check(bool(bought.get("ok", false)), "club gloves purchase failed")
    _check(int(game_state.state.career.money) == before_money - 60000, "equipment purchase did not spend money")
    _check(int(game_state.state.boxer.power) == before_power + 1, "club gloves did not add direct power")
    _check(str(game_state.current_equipment("personal", "gloves").get("id", "")) == "club_gloves", "purchased gloves were not stored")
    _check(game_state.equipment_total_spent() == 60000, "equipment spending total was not tracked")

func _test_title_locked_upgrades() -> void:
    game_state.state.career.money = 999999
    var locked: Dictionary = game_state.can_purchase_equipment("personal", "pro_gloves")
    _check(not bool(locked.get("ok", false)) and str(locked.get("reason", "")) == "locked", "pro gear unlocked before regional title")

    var career_state: Dictionary = game_state.state.get("career_state", {}).duplicate(true)
    career_state["ladder_titles"] = ["district", "regional"]
    game_state.state["career_state"] = career_state
    var unlocked: Dictionary = game_state.can_purchase_equipment("personal", "pro_gloves")
    _check(bool(unlocked.get("ok", false)), "pro gear did not unlock after regional title")
    var bought: Dictionary = game_state.purchase_equipment("personal", "pro_gloves")
    _check(bool(bought.get("ok", false)), "pro gloves purchase failed after unlock")
    _check(int(game_state.current_equipment("personal", "gloves").get("tier", 0)) == 2, "personal equipment did not upgrade sequentially")

func _test_gym_equipment_improves_training_over_time() -> void:
    game_state.new_career("Gym Boxer", "workhorse")
    game_state.state.phase = "camp"
    game_state.state.career.money = 999999
    var bought: Dictionary = game_state.purchase_equipment("gym", "club_mitts")
    _check(bool(bought.get("ok", false)), "club mitts purchase failed")
    _check(game_state.gym_training_percent("mitts") > 0.0, "purchased mitts provide no training effect")

    var mitts := _find_camp_action("mitts")
    _check(not mitts.is_empty(), "mitts fixture missing")
    if mitts.is_empty():
        return

    var received_bonus := false
    for index in range(3):
        game_state.state.phase = "camp"
        game_state.state.career.money = 999999
        var result: Dictionary = game_state.apply_camp_action(mitts)
        _check(bool(result.get("ok", false)), "mitt training failed during equipment carry test")
        if not result.get("equipment_growth_bonus", {}).is_empty():
            received_bonus = true
    _check(received_bonus, "gym equipment never converted accumulated training efficiency into growth")

func _test_new_career_resets_equipment() -> void:
    _check(not game_state.current_equipment("gym", "mitts").is_empty(), "gym equipment fixture missing before reset")
    game_state.new_career("Next Boxer", "technician")
    _check(game_state.current_equipment("personal", "gloves").is_empty(), "personal equipment leaked into the next career")
    _check(game_state.current_equipment("gym", "mitts").is_empty(), "gym equipment leaked into the next career")
    _check(game_state.equipment_total_spent() == 0, "equipment spending leaked into the next career")

func _find_camp_action(action_id: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_actions.json"))
    if typeof(parsed) != TYPE_ARRAY:
        return {}
    for value in parsed:
        var action: Dictionary = value
        if str(action.get("id", "")) == action_id:
            return action.duplicate(true)
    return {}

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(game_state):
        game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("equipment-economy-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
