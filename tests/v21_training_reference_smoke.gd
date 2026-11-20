extends SceneTree

const MAIN_PATH := "res://scenes/Main.tscn"
const PROFILE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

var failures: Array[String] = []
var state_node: Node
var main: Control

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: tests require an isolated user-data directory")
        quit(2)
        return

    state_node = root.get_node("GameState")
    var actions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_actions.json"))
    _require(actions.size() == 8, "expected eight existing camp actions")
    for action: Dictionary in actions:
        await _check_action(action)
    await _check_eligibility()
    await _check_resume()

    if failures.is_empty():
        print("PASS: eight actions, actual results, eligibility, duplicate input, profile and save/resume")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)

func _open_camp() -> void:
    state_node.new_career("트레이닝 QA", "technician")
    state_node.state["first_launch_acknowledged"] = true
    state_node.state["phase"] = "camp"
    var boxer: Dictionary = state_node.state["boxer"]
    boxer["fatigue"] = 40
    boxer["health"] = 76
    boxer["weight_kg"] = 61.8
    boxer["modifiers"] = {}
    state_node.rng.seed = 42

func _enter_scene() -> void:
    var scene := load(MAIN_PATH) as PackedScene
    main = scene.instantiate()
    root.add_child(main)
    await _settle()

func _close_scene() -> void:
    main.queue_free()
    await process_frame

func _settle() -> void:
    await process_frame
    await process_frame

func _check_action(action: Dictionary) -> void:
    _open_camp()
    var id := str(action["id"])
    if id == "rehab":
        state_node.state["boxer"]["injury"] = state_node.injuries[2].duplicate(true)
    await _enter_scene()
    var training := main.find_child("ReferenceTraining", true, false)
    _require(training != null, "training screen not rendered")
    if training == null:
        await _close_scene()
        return

    var grid := training.find_child("TrainingPrimaryGrid", true, false) as GridContainer
    _require(grid != null and grid.columns == 2 and grid.get_child_count() == 4, "primary 2×2 grid")
    _require(training.find_child("TrainingHeroPhoto", true, false) != null, "hero photo")
    for meter in ["Health", "Fatigue"]:
        var bar := training.find_child("Training%sMeter" % meter, true, false) as ProgressBar
        _require(bar != null and int(bar.value) == (76 if meter == "Health" else 40), "live " + meter)
    var extras := training.find_child("TrainingAdditionalActions", true, false) as Control
    _require(extras != null and not extras.visible, "additional actions start collapsed")
    var choose := training.find_child("TrainingSelect_" + id, true, false) as Button
    if choose == null:
        _require(false, "missing action " + id)
        await _close_scene()
        return
    if not choose.is_visible_in_tree():
        (training.find_child("TrainingMoreActions", true, false) as Button).pressed.emit()
        await _settle()
    _require(choose.is_visible_in_tree() and not choose.disabled, id + " should be selectable")

    var before: Dictionary = state_node.state["boxer"].duplicate(true)
    var money := int(state_node.state["career"]["money"])
    choose.pressed.emit()
    choose.pressed.emit()
    await _settle()
    _require(str(state_node.state["phase"]) == "fight_offer", id + " advances to fight offers")
    _require(main.find_child("ReferenceTraining", true, false) == null, id + " removes old choices")
    _require(int(state_node.state["career"]["money"]) == money - int(action["cost"]), id + " charged exactly once")

    var after: Dictionary = state_node.state["boxer"]
    var effects: Dictionary = action["effects"]
    for stat: String in PROFILE_STATS + ["health", "fatigue", "weight_kg"]:
        var effect_key := "weight" if stat == "weight_kg" else stat
        var delta := float(effects.get(effect_key, 0))
        _require(is_equal_approx(float(after[stat]), float(before[stat]) + delta), id + " changed " + stat)
    if id == "rehab":
        _require(after["injury"].is_empty(), "rehab cleared the injury")

    var panel := main.find_child("TrainingResult", true, false)
    _require(panel != null, id + " result visible at fight offers")
    if panel != null:
        var changes: Dictionary = state_node.state["last_camp_result"]["changes"]
        for stat in effects:
            if stat != "injury_camps":
                _require(is_equal_approx(float(changes.get(stat, 0)), float(effects[stat])), id + " result for " + stat)
        var labels := _texts(panel)
        _require(("현재 건강 %d / 100   ·   피로 %d / 100" % [int(after["health"]), int(after["fatigue"])]) in labels, id + " result condition")
        if id == "rehab":
            _require(_contains(labels, "부상 회복"), "rehab result text")

    _check_saved_action(id)
    await _check_profile(after)
    (main.v17_nav_buttons["training"] as Button).pressed.emit()
    await _settle()
    _require(main.find_child("ReferenceTraining", true, false) == null, "completed camp cannot be repeated")
    _require(main.find_child("TrainingResult", true, false) != null, "completed result can be reopened")
    await _close_scene()

func _check_eligibility() -> void:
    _open_camp()
    state_node.state["career"]["money"] = 5000
    await _enter_scene()
    var training := main.find_child("ReferenceTraining", true, false)
    var extra := training.find_child("TrainingMoreActions", true, false) as Button
    extra.pressed.emit()
    var before: Dictionary = state_node.state.duplicate(true)
    for button in training.find_children("TrainingSelect_*", "Button", true, false):
        if button.name == "TrainingSelect_full_rest":
            _require(not button.disabled, "a choice costing exactly the balance stays enabled")
        else:
            _require(button.disabled, str(button.name) + " disabled at low balance")
            button.pressed.emit()
    await _settle()
    _require(state_node.state == before, "disabled choices cannot mutate the career")
    await _check_profile(before["boxer"])
    (main.v17_nav_buttons["training"] as Button).pressed.emit()
    await _settle()
    _require(main.find_child("ReferenceTraining", true, false) != null, "eligible camp reopens after viewing profile")
    _require(state_node.state == before, "tab switching preserves the career")
    (main.find_child("TrainingSelect_full_rest", true, false) as Button).pressed.emit()
    await _settle()
    _require(int(state_node.state["career"]["money"]) == 0, "affordable rest applies at exact balance")
    await _close_scene()

func _check_saved_action(id: String) -> void:
    var persisted := SaveService.load_game()
    _require(str(persisted.get("phase", "")) == "fight_offer", id + " saved the next phase")
    _require(str(persisted.get("last_camp_action", "")) == id, id + " saved the choice")
    _require(str(persisted.get("last_camp_result", {}).get("action_id", "")) == id, id + " saved the result")
    var current_boxer: Dictionary = state_node.state["boxer"]
    var saved_boxer: Dictionary = persisted.get("boxer", {})
    for key in PROFILE_STATS + ["fatigue", "health", "weight_kg"]:
        _require(is_equal_approx(float(saved_boxer.get(key, -1)), float(current_boxer[key])), id + " saved " + key)
    _require(int(persisted.get("career", {}).get("money", -1)) == int(state_node.state["career"]["money"]), id + " saved money")

func _check_profile(boxer: Dictionary) -> void:
    (main.v17_nav_buttons["profile"] as Button).pressed.emit()
    await _settle()
    var profile := main.find_child("ReferenceProfile", true, false)
    _require(profile != null, "profile opens")
    if profile == null:
        return
    var labels := _texts(profile)
    _require(("%d%%" % int(boxer["fatigue"])) in labels, "profile fatigue in sync")
    _require(("%d / 100" % int(boxer["health"])) in labels, "profile health in sync")
    var bars := profile.find_children("*", "ProgressBar", true, false)
    _require(bars.size() == PROFILE_STATS.size(), "profile has five stats")
    for index in range(mini(bars.size(), PROFILE_STATS.size())):
        _require(int(bars[index].value) == int(boxer[PROFILE_STATS[index]]), "profile " + PROFILE_STATS[index] + " in sync")

func _check_resume() -> void:
    state_node.state = SaveService.load_game()
    await _enter_scene()
    _require(main.find_child("TrainingResult", true, false) != null, "restored fight offers show result")
    await _check_profile(state_node.state["boxer"])
    await _close_scene()

    state_node.state.erase("last_camp_result")
    await _enter_scene()
    _require(str(state_node.state["phase"]) == "fight_offer", "older saves keep their phase")
    _require(main.find_child("TrainingResult", true, false) == null, "older saves use the normal offer screen")
    await _close_scene()

func _texts(parent: Node) -> Array[String]:
    var texts: Array[String] = []
    for item in parent.find_children("*", "Label", true, false):
        texts.append(item.text)
    return texts

func _contains(labels: Array[String], value: String) -> bool:
    for label in labels:
        if label.contains(value):
            return true
    return false

func _require(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
