extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        quit(2)
        return
    var game := root.get_node("GameState")
    game.new_career("준비 복원", "technician")
    game.state.first_launch_acknowledged = true
    var roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    game.state.phase = "fight_offer"
    game.select_opponent(roster[0])
    check(game.state.phase == "game_plan", "selection opens scouting")
    for phase: String in ["tactical_prep", "condition_prep"]:
        game.state.phase = phase
        game.state.selected_tactical_prep = "distance_drill" if phase == "condition_prep" else ""
        SaveService.save_game(game.state)
        var restored := SaveService.load_game()
        check(restored.phase == "game_plan" and restored.selected_opponent == roster[0].id, "resume old " + phase)
        check(restored.selected_tactical_prep == game.state.selected_tactical_prep, "keep previously selected tactic")
        game.state = restored
    var view: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(view)
    await process_frame
    var report := view.find_child("ReferenceScouting", true, false)
    check(report != null, "restored opponent report")
    if report != null:
        var open: Button = report.find_child("ScoutingShowPlans", true, false)
        open.pressed.emit()
        var plans := report.find_children("GamePlanSelect_*", "Button", true, false)
        check(plans.size() == game.game_plans.size(), "all five plans")
        for plan: Button in plans:
            check(plan.is_visible_in_tree(), "plan available")
        var choose: Button = report.find_child("GamePlanSelect_pressure", true, false)
        choose.pressed.emit()
        await process_frame
        check(game.state.phase == "fight" and game.state.selected_game_plan == "pressure", "selected plan and weigh-in")
        var restored := SaveService.load_game()
        check(restored.last_weigh_in.status == game.state.last_weigh_in.status and is_equal_approx(float(restored.last_weigh_in.over_kg), float(game.state.last_weigh_in.over_kg)), "weigh-in survives restart")
    # Let SceneTree own teardown after the test instead of reentering UI destruction.
    await process_frame
    if failures.is_empty():
        print("PASS: direct scouting, old preparation saves, plan selection and weigh-in")
    quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
