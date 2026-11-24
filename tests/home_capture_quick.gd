extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    print("QUICK_START user_data=", OS.get_user_data_dir())
    var game := root.get_node_or_null("GameState")
    if game == null:
        printerr("NO_GAMESTATE")
        quit(2)
        return
    game.new_career("김도현", "technician")
    game.state["first_launch_acknowledged"] = true
    game.state.erase("first_cycle_tutorial")
    game.state["phase"] = "camp"
    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    print("UI_READY phase=", game.state.get("phase"), " children=", ui.get_child_count())
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui.launch_gate_active = false
    ui.v17_overlay = "home"
    ui._render_phase()
    print("HOME_REQUESTED")
    await process_frame
    await process_frame
    print("HOME_NODE=", ui.find_child("ReferenceHome", true, false), " BODY=", ui.find_child("V17ContentScroll", true, false))
    await process_frame
    var img := root.get_texture().get_image()
    print("IMAGE=", img.get_width(), "x", img.get_height())
    var err := img.save_png("res://docs/ui-audit/home-dashboard-runtime.png")
    print("SAVE=", err)
    quit(0)
