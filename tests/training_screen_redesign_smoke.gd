extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("김도현", "technician")
    game.state["first_launch_acknowledged"] = true
    game.state["phase"] = "camp"
    game.state["career"]["money"] = 120000
    game.state["first_cycle_tutorial"] = {"active": true, "complete": false, "talent_roll_seen": true, "actions_seen": []}

    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._guide_settings.set_value("tutorial", "enabled", true)
    ui._guide_settings.save("user://first_bout_guide.cfg")
    ui.launch_gate_active = false
    ui.v17_overlay = ""
    ui._render_phase()
    await process_frame
    await process_frame

    var training := ui.find_child("ReferenceTraining", true, false)
    _check(training != null, "training screen missing")
    _check(ui.find_child("TrainingCoachBanner", true, false) != null, "inline coach banner missing")
    _check(ui.find_child("FirstCycleSpotlight", true, false) == null, "floating spotlight must not cover camp")
    _check(ui.find_child("TrainingPrimaryList", true, false) != null, "vertical training list missing")
    _check(ui.find_child("TrainingBodyCareList", true, false) != null, "vertical recovery list missing")
    _check(ui.find_child("TrainingActionDock", true, false) != null, "fixed action dock missing")

    var sparring := ui.find_child("TrainingSelect_sparring", true, false) as Button
    var execute := ui.find_child("TrainingExecute", true, false) as Button
    _check(sparring != null and execute != null and execute.disabled, "initial training selection state invalid")
    if sparring != null:
        sparring.pressed.emit()
    await process_frame
    _check(not execute.disabled and execute.text.contains("스파링"), "fixed action button did not follow selection")

    if DisplayServer.get_name() != "headless":
        var viewport_texture := root.get_texture()
        if viewport_texture != null:
            var screenshot := viewport_texture.get_image()
            if screenshot != null:
                screenshot.save_png("res://docs/ui-audit/training-screen-redesign.png")

    if failures.is_empty():
        print("PASS: inline coach, vertical cards, no spotlight, fixed action dock, selection binding")
        quit(0)
    else:
        for failure in failures:
            printerr("FAIL: ", failure)
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
