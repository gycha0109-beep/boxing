extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("김도현", "technician")
    game.state["first_launch_acknowledged"] = true
    game.state.erase("first_cycle_tutorial")
    game.state["phase"] = "camp"
    game.state["boxer"]["health"] = 92
    game.state["boxer"]["fatigue"] = 12
    game.state["career"]["money"] = 120000
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
    print("TRAINING_NODE=", ui.find_child("ReferenceTraining", true, false))
    var image := root.get_texture().get_image()
    print("CAPTURE_SIZE=", image.get_width(), "x", image.get_height())
    print("SAVE=", image.save_png("res://docs/ui-audit/training-screen-runtime-before.png"))
    var scroll := ui.find_child("V17ContentScroll", true, false) as ScrollContainer
    if scroll != null:
        scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
        await process_frame
        await process_frame
        var bottom_image := root.get_texture().get_image()
        print("BOTTOM_SAVE=", bottom_image.save_png("res://docs/ui-audit/training-screen-runtime-bottom.png"))
    quit(0)
