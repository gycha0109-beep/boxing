extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("Refusing to run outside isolated test user data.")
        quit(2)
        return

    var game := root.get_node("GameState")
    game.new_career("실시간 UI 검증", "technician")
    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame

    var before: Dictionary = game.state.duplicate(true)
    var refresh_button := ui.find_child("DevLiveUIRefreshButton", true, false) as Button
    if refresh_button == null:
        printerr("FAIL: live refresh button was not installed.")
        quit(1)
        return

    refresh_button.emit_signal("pressed")
    await process_frame
    await process_frame
    await process_frame
    refresh_button.emit_signal("pressed")
    await process_frame
    await process_frame
    await process_frame

    var title_after := ui.find_child("ReferenceTitle", true, false)
    var state_unchanged: bool = game.state == before
    var refreshed := int(ui.get("_dev_ui_refresh_count")) == 2
    if title_after == null or not state_unchanged or not refreshed:
        printerr("FAIL: repeated button presses did not rebuild title or GameState changed.")
        quit(1)
        return

    print("PASS: live refresh button rebuilds title, increments feedback, and preserves GameState.")
    ui.queue_free()
    await process_frame
    quit(0)
