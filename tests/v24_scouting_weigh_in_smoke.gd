extends SceneTree

var failures: Array[String] = []
var career: Node
var game: Control
var main_scene: PackedScene

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: tests require an isolated user-data directory")
        quit(2)
        return
    career = root.get_node("GameState")
    # Hold the packed resources while recreating the view for each restore.
    main_scene = load("res://scenes/Main.tscn") as PackedScene
    await _check_weigh_in(60.9, "pass", "계체 통과", "")
    await _check_weigh_in(61.7, "emergency_cut", "긴급 감량 통과", "건강 -3 · 피로 +5")
    await _check_weigh_in(62.4, "miss", "계체 실패", "68%")
    await _check_weigh_in(62.9, "miss", "계체 실패", "51%")
    await _check_legacy_resume_and_entry()
    await _dispose_game()
    main_scene = null
    career = null
    await create_timer(0.5).timeout
    if failures.is_empty():
        print("PASS: scouting, plan navigation, all weigh-in verdicts, rollback, legacy restore and fight entry")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)

func _check_weigh_in(weight: float, status: String, verdict: String, detail: String) -> void:
    career.new_career("계체 QA", "technician")
    career.state["first_launch_acknowledged"] = true
    career.state["boxer"]["weight_kg"] = weight
    career.state["boxer"]["health"] = 3
    career.state["boxer"]["fatigue"] = 95
    career.state["career"]["reputation"] = 2
    var opponents: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    career.state.phase = "fight_offer"
    career.select_opponent(opponents[0])
    await _open_game()

    var scouting := game.find_child("ReferenceScouting", true, false)
    _require(scouting != null, "scouting screen is rendered")
    if scouting == null:
        await _close_game()
        return
    var scroll := game.find_child("V17ContentScroll", true, false) as ScrollContainer
    var before := SaveService.load_game()
    var plans := scouting.find_child("ScoutingPlans", true, false) as Control
    _require(plans != null and not plans.is_visible_in_tree(), "scouting initially shows the report alone")
    var comparison := scouting.find_child("ScoutingComparison", true, false) as Control
    _require(comparison != null, "scouting renders the side-by-side comparison")
    var tendency := scouting.find_child("ScoutingTendency_body", true, false) as Label
    _require(tendency != null and tendency.text == "%d%%" % roundi(float(opponents[0]["tendencies"]["body"]) * 100.0), "scouting reads the actual roster tendency")
    if _press("ScoutingShowPlans"):
        await _settle()
        _require(plans != null and plans.is_visible_in_tree() and comparison != null and not comparison.is_visible_in_tree(), "plan shortcut opens a separate view")
        _require(scroll.scroll_vertical == 0, "plan view starts from the top")
        for button in plans.find_children("*", "Button", true, false):
            if button.text == "← 상대 분석":
                button.pressed.emit()
                break
        await _settle()
        _require(not plans.is_visible_in_tree() and comparison.is_visible_in_tree(), "back returns to scouting")
        _press("ScoutingShowPlans")
        await _settle()
        _require(SaveService.load_game() == before, "preview does not change the save")
    var meters := comparison.find_children("*", "ProgressBar", true, false) if comparison != null else []
    _require(meters.size() == 10, "scouting compares five values per player")
    if meters.size() == 10:
        var stats: Array[String] = ["power", "speed", "technique", "defense", "conditioning"]
        var prepared: Dictionary = career.get_fight_boxer()
        for index in range(stats.size()):
            _require(int(meters[index * 2].value) == int(prepared[stats[index]]), "actual prepared boxer stats")
            _require(int(meters[index * 2 + 1].value) == int(opponents[0]["stats"][stats[index]]), "actual opponent stats")

    if not _press("GamePlanSelect_counter_trap"):
        await _close_game()
        return
    await _settle()
    var result: Dictionary = career.state["last_weigh_in"]
    _require(str(result.get("status", "")) == status, "actual verdict for %.2f kg" % weight)
    var label := game.find_child("WeighInVerdict", true, false) as Label
    _require(label != null and label.text == verdict, "correct verdict text")
    if not detail.is_empty():
        _require(_has_text(detail), "correct impact for %.2f kg" % weight)
    if status == "miss":
        _require(_has_text("평판 -2"), "penalty respects the actual reputation floor")
    var expected := float(career.career_balance["weight_class"]["limit_kg"]) if status == "emergency_cut" else weight
    _require(_has_text("%.2f kg" % expected), "weigh-in shows the actual measured weight")
    _require(_has_text("카운터 함정"), "weigh-in shows the selected plan")
    _require(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "weigh-in content can scroll")
    var snapshot := SaveService.load_game()
    await _close_game()
    career.state = snapshot
    await _open_game()
    _require(_has_text(verdict), "confirmed verdict survives restart")
    for button in game.find_children("*", "Button", true, false):
        if button.text == "← 게임플랜 다시 선택":
            button.pressed.emit()
            break
    await _settle()
    _require(career.state["phase"] == "game_plan", "return to plan after weigh-in")
    for field in ["weight_kg", "fatigue", "health"]:
        _require(is_equal_approx(float(career.state["boxer"][field]), float(before["boxer"][field])), "undo the weigh-in effect on " + field)
    _require(int(career.state["career"]["reputation"]) == int(before["career"]["reputation"]), "undo the reputation penalty")
    _require(career.state["selected_condition_prep"] == "", "no extra condition activity")
    await _close_game()

func _check_legacy_resume_and_entry() -> void:
    # Older saves can reach weigh-in without a rollback snapshot.
    career.state["boxer"]["health"] = 90
    career.state["boxer"]["weight_kg"] = 60.9
    career.select_game_plan("balanced")
    career.state["weigh_in_acknowledged"] = false
    career.state.erase("pre_game_plan_snapshot")
    SaveService.save_game(career.state)
    career.state = SaveService.load_game()
    await _open_game()
    _require(_has_text("공식 계체"), "older save renders its pending weigh-in")
    for button in game.find_children("*", "Button", true, false):
        _require(button.text != "← 게임플랜 다시 선택", "no unavailable rollback on an older save")
    if _press("WeighInEnterFight"):
        await _settle()
        _require(bool(career.state.get("weigh_in_acknowledged", false)), "fight entry acknowledges the weigh-in")
        _require(game.find_child("FightStage", true, false) != null, "fight scene renders")
        _require(game.find_child("ReferenceWeighIn", true, false) == null, "weigh-in dismissed")
        var scroll := game.find_child("V17ContentScroll", true, false) as ScrollContainer
        _require(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "fight keeps its fixed controls")
    await _close_game()

func _open_game() -> void:
    if not is_instance_valid(game):
        game = main_scene.instantiate()
        root.add_child(game)
    else:
        game.set("current_opponent", {})
        game.set("combat", null)
        game.set("v17_overlay", "")
        game.call("_render_phase")
    await _settle()

func _close_game() -> void:
    await _settle()

func _dispose_game() -> void:
    if is_instance_valid(game):
        game.queue_free()
        await process_frame
        game = null
    await create_timer(0.25).timeout

func _settle() -> void:
    await process_frame
    await process_frame

func _press(id: String) -> bool:
    var button := game.find_child(id, true, false) as Button
    _require(button != null, id + " is rendered")
    if button == null:
        return false
    button.pressed.emit()
    return true

func _has_text(text: String) -> bool:
    for label in game.find_children("*", "Label", true, false):
        if label.text.contains(text):
            return true
    return false

func _require(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error(reason)
