extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("탭 UI 점검", "technician")
    game.state["first_launch_acknowledged"] = true
    game.state.erase("first_cycle_tutorial")
    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui.launch_gate_active = false
    ui.v17_overlay = "home"
    ui._render_phase()
    await process_frame
    var keys: Array = ui.v17_nav_buttons.keys()
    print("NAV_KEYS=", keys)
    for key_value in keys:
        var key := str(key_value)
        var button := ui.v17_nav_buttons[key] as Button
        if button == null:
            continue
        button.pressed.emit()
        await process_frame
        await process_frame
        var safe := "nav-" + key + ".png"
        var image := root.get_texture().get_image()
        image.save_png("res://docs/ui-audit/" + safe)
        print("CAPTURE=", safe, " BODY_CHILDREN=", ui.body.get_child_count())
    ui._v19_open_menu()
    await process_frame
    await process_frame
    var settings_image := root.get_texture().get_image()
    settings_image.save_png("res://docs/ui-audit/nav-settings.png")
    print("CAPTURE=nav-settings.png")
    ui.queue_free()
    await process_frame
    quit(0)
