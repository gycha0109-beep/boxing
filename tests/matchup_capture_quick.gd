extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("김도현", "technician")
    game.state["first_launch_acknowledged"] = true
    game.state.erase("first_cycle_tutorial")
    var roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    game.state["phase"] = "fight_offer"
    game.select_opponent(roster[0])
    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui.launch_gate_active = false
    ui.v17_overlay = ""
    ui._render_phase()
    await process_frame
    await process_frame
    var view := ui.find_child("ReferenceMatchup", true, false)
    print("MATCHUP_NODE=", view)
    print("PLAN_BUTTONS=", view.find_children("MatchPlanSelect_*", "Button", true, false).size() if view != null else -1)
    var image := root.get_texture().get_image()
    print("CAPTURE_SIZE=", image.get_width(), "x", image.get_height())
    print("SAVE=", image.save_png("res://docs/ui-audit/matchup-screen-runtime.png"))
    if view != null:
        var scroll := ui.find_child("V17ContentScroll", true, false) as ScrollContainer
        if scroll != null:
            scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
            await process_frame
            await process_frame
            var bottom_image := root.get_texture().get_image()
            bottom_image.save_png("res://docs/ui-audit/matchup-screen-runtime-bottom.png")
        var plans := view.find_children("MatchPlanSelect_*", "Button", true, false)
        if plans.size() > 1:
            plans[1].pressed.emit()
        var confirm := view.find_child("MatchupConfirmPlan", true, false) as Button
        confirm.pressed.emit()
        await process_frame
        print("AFTER_CONFIRM_PHASE=", game.state.get("phase"), " SELECTED_PLAN=", game.state.get("selected_game_plan"))
    quit(0)
