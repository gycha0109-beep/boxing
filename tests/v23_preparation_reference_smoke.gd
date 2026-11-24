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
    game.state.erase("first_cycle_tutorial")
    var roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    game.state.phase = "fight_offer"
    game.select_opponent(roster[0])
    check(game.state.phase == "game_plan", "opponent selection opens match preparation")
    for phase: String in ["tactical_prep", "condition_prep"]:
        game.state.phase = phase
        game.state.selected_tactical_prep = "distance_drill" if phase == "condition_prep" else ""
        SaveService.save_game(game.state)
        var restored := SaveService.load_game()
        check(restored.phase == "game_plan" and restored.selected_opponent == roster[0].id, "resume old " + phase)
        check(restored.selected_tactical_prep == game.state.selected_tactical_prep, "keep previously selected tactic")
        game.state = restored

    var main: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    await process_frame
    main.launch_gate_active = false
    main.v17_overlay = ""
    main._render_phase()
    await process_frame
    var matchup := main.find_child("ReferenceMatchup", true, false)
    check(matchup != null, "reference match preparation renders")
    if matchup != null:
        var plans := matchup.find_children("MatchPlanSelect_*", "Button", true, false)
        check(plans.size() == game.game_plans.size(), "all five strategies are available")
        var choose := matchup.find_child("MatchPlanSelect_pressure", true, false) as Button
        check(choose != null, "pressure strategy is present")
        if choose != null:
            choose.pressed.emit()
            check(str(matchup.selected_plan_id) == "pressure", "selected strategy updates the active card")
        var confirm := matchup.find_child("MatchupConfirmPlan", true, false) as Button
        check(confirm != null, "matchup confirmation action exists")
        if confirm != null:
            confirm.pressed.emit()
            await process_frame
            check(game.state.phase == "fight" and game.state.selected_game_plan == "pressure", "selected strategy starts the fight")
            var restored := SaveService.load_game()
            check(restored.last_weigh_in.status == game.state.last_weigh_in.status and is_equal_approx(float(restored.last_weigh_in.over_kg), float(game.state.last_weigh_in.over_kg)), "weigh-in survives restart")

    if is_instance_valid(main):
        main.queue_free()
        await process_frame
    await process_frame
    if failures.is_empty():
        print("PASS: old preparation saves, five strategy cards, selection, fight transition and weigh-in persistence")
    else:
        printerr("FAIL: ", failures)
    quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
