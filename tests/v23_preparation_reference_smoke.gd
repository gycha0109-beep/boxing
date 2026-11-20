extends SceneTree

var failures: Array[String] = []
var career: Node
var game: Control

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: tests require an isolated user-data directory")
        quit(2)
        return

    career = root.get_node("GameState")
    career.new_career("경기 준비 QA", "technician")
    career.state["first_launch_acknowledged"] = true
    career.state["boxer"]["health"] = 76
    career.state["boxer"]["fatigue"] = 40
    await _enter_game()
    if not _press("TrainingSelect_roadwork"):
        _finish()
        return
    await _settle()
    if not _press("FightOfferSelect_han_do-yun"):
        _finish()
        return
    await _settle()

    var tactics: Array = career.tactical_preparations()
    _require(tactics.size() == 4, "all four tactical choices are available")
    for tactical: Dictionary in tactics:
        await _check_tactical(tactical)

    if not _press("PreparationSelect_distance_drill") or not _press("PreparationConfirm"):
        _finish()
        return
    await _settle()
    var conditions: Array = career.condition_preparations()
    _require(conditions.size() == 3, "all three condition choices are available")
    for condition: Dictionary in conditions:
        await _check_condition(condition)
    await _check_weigh_in_and_resume()
    _finish()

func _check_tactical(tactical: Dictionary) -> void:
    var id := str(tactical["id"])
    var before: Dictionary = career.state.duplicate(true)
    var saved_before := SaveService.load_game()
    var confirm := _button("PreparationConfirm")
    if confirm == null:
        return
    _require(confirm.disabled, "continue disabled until a tactic is selected")
    confirm.pressed.emit()
    _require(career.state == before, "cannot confirm without a tactic")

    if not _press("PreparationSelect_distance_drill") or not _press("PreparationSelect_" + id):
        return
    var pressed := game.find_children("PreparationSelect_*", "Button", true, false).filter(
        func(button: Button) -> bool: return button.button_pressed,
    )
    _require(pressed.size() == 1 and pressed[0].name == "PreparationSelect_" + id, id + " highlights only the current choice")
    _require(career.state == before and SaveService.load_game() == saved_before, id + " preview preserves state and save")
    _require(not confirm.disabled, id + " enables confirm")
    confirm.pressed.emit()
    confirm.pressed.emit()
    await _settle()
    _require(_phase() == "condition_prep", id + " advances to condition prep")
    _require(career.state["selected_tactical_prep"] == id, id + " saved tactic")
    var boxer: Dictionary = career.get_fight_boxer()
    for action in tactical["action_modifiers"]:
        for stat in tactical["action_modifiers"][action]:
            var actual: Dictionary = boxer["game_plan"]["action_modifiers"].get(action, {})
            _require(int(actual.get(stat, 0)) == int(tactical["action_modifiers"][action][stat]), id + " real tactical effect")
    _require(career.state["boxer"] == before["boxer"], id + " does not change permanent stats")
    _press("PreparationBack")
    await _settle()
    _require(_phase() == "tactical_prep" and career.state["selected_tactical_prep"] == "", id + " tactic can be changed")

func _check_condition(condition: Dictionary) -> void:
    var id := str(condition["id"])
    var before: Dictionary = career.state.duplicate(true)
    var boxer_before: Dictionary = before["boxer"]
    var fight_before: Dictionary = career.get_fight_boxer()
    var confirm := _button("PreparationConfirm")
    if confirm == null or not _press("PreparationSelect_" + id):
        return
    _require(career.state == before, id + " preview preserves athlete state")
    confirm.pressed.emit()
    confirm.pressed.emit()
    await _settle()
    _require(_phase() == "game_plan" and career.state["selected_condition_prep"] == id, id + " advances to game plan")
    var immediate: Dictionary = condition.get("immediate", {})
    var boxer: Dictionary = career.state["boxer"]
    _require(int(boxer["fatigue"]) == clampi(int(boxer_before["fatigue"]) + int(immediate.get("fatigue", 0)), 0, 100), id + " affects fatigue once")
    _require(int(boxer["health"]) == clampi(int(boxer_before["health"]) + int(immediate.get("health", 0)), 0, 100), id + " updates health")
    _require(is_equal_approx(float(boxer["weight_kg"]), float(boxer_before["weight_kg"]) + float(immediate.get("weight", 0))), id + " updates weight")
    var fight_boxer: Dictionary = career.get_fight_boxer()
    for stat in condition.get("global_stats", {}):
        _require(int(boxer[stat]) == int(boxer_before[stat]), id + " does not permanently change " + str(stat))
        _require(int(fight_boxer[stat]) == int(fight_before[stat]) + int(condition["global_stats"][stat]), id + " changes fight-only " + str(stat))
    _require(SaveService.load_game().get("selected_condition_prep", "") == id, id + " saved condition choice")
    await _press_text("← 컨디션 다시 선택")
    _require(_phase() == "condition_prep", id + " can go back from game plan")
    _require(career.state["boxer"] == boxer_before, id + " back restores condition snapshot")
    _require(career.state["selected_tactical_prep"] == "distance_drill", id + " back keeps the prior tactic")

func _check_weigh_in_and_resume() -> void:
    if not _press("PreparationSelect_weight_control") or not _press("PreparationConfirm"):
        return
    await _settle()
    var pre_weigh: Dictionary = career.state["boxer"].duplicate(true)
    await _press_text("이 플랜 선택")
    _require(_phase() == "fight" and not bool(career.state.get("weigh_in_acknowledged", true)), "game plan advances to official weigh-in")
    _require("공식 계체" in _labels(), "official weigh-in rendered")
    _require(str(career.state.get("last_weigh_in", {}).get("status", "")) == "pass", "weight control carried through to successful weigh-in")
    var saved := SaveService.load_game()
    _require(saved.get("selected_tactical_prep", "") == "distance_drill", "saved tactic at weigh-in")
    _require(saved.get("selected_condition_prep", "") == "weight_control", "saved condition at weigh-in")
    _require(not str(saved.get("selected_game_plan", "")).is_empty(), "saved game plan at weigh-in")
    game.queue_free()
    await process_frame
    career.state = saved
    await _enter_game()
    _require("공식 계체" in _labels(), "reload returns to official weigh-in")
    await _press_text("← 게임플랜 다시 선택")
    _require(_phase() == "game_plan", "weigh-in allows game plan changes")
    _require(is_equal_approx(float(career.state["boxer"]["weight_kg"]), float(pre_weigh["weight_kg"])), "weigh-in back keeps the confirmed weight adjustment")
    _require(career.state["selected_tactical_prep"] == "distance_drill" and career.state["selected_condition_prep"] == "weight_control", "weigh-in back keeps preparation choices")

func _phase() -> String:
    return str(career.state.get("phase", ""))

func _enter_game() -> void:
    var scene := load("res://scenes/Main.tscn") as PackedScene
    game = scene.instantiate()
    root.add_child(game)
    await _settle()

func _settle() -> void:
    await process_frame
    await process_frame

func _button(node_name: String) -> Button:
    var button := game.find_child(node_name, true, false) as Button
    _require(button != null, node_name + " is present")
    return button

func _press(node_name: String) -> bool:
    var button := _button(node_name)
    if button == null:
        return false
    button.pressed.emit()
    return true

func _press_text(text: String) -> void:
    for button in game.find_children("*", "Button", true, false):
        if button.text == text:
            button.pressed.emit()
            await _settle()
            return
    _require(false, text + " action is present")

func _labels() -> Array[String]:
    var result: Array[String] = []
    for label in game.find_children("*", "Label", true, false):
        result.append(label.text)
    return result

func _require(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error(reason)

func _finish() -> void:
    if is_instance_valid(game):
        game.queue_free()
        await process_frame
    if failures.is_empty():
        print("PASS: seven preparation options, single confirmation, real effects, rollback, weigh-in and resume")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)
