extends SceneTree

const Business = preload("res://scripts/core/boxing_business_service.gd")
var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        quit(2)
        return
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("Sponsor Visual", "workhorse")
    game.state.career.fights = 3
    game.state.career.reputation = 25
    game.state.career_state["ladder_titles"] = ["district"]
    _check(Business.enter_offer_if_due(game.state), "Cannot enter sponsor offer")
    game.state.first_launch_acknowledged = true
    SaveService.save_game(game.state)

    var screen := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(screen)
    await process_frame
    screen.launch_gate_active = false
    screen.v17_overlay = ""
    screen._render_phase()
    await process_frame
    await process_frame
    var buttons: Array = []
    for item in screen.find_children("*", "Button", true, false):
        if str(item.name).begins_with("Sponsor_"):
            buttons.append(item)
    print("Sponsor visual buttons: ", buttons.map(func(item: Node): return str(item.name)))
    _check(buttons.size() >= 2, "Sponsor contract styles missing")
    var decline_button := false
    for item in screen.find_children("*", "Button", true, false):
        if (item as Button).text.contains("계약하지 않기"):
            decline_button = true
    _check(decline_button, "Sponsor decline option missing")
    for item in buttons:
        var button := item as Button
        if button == null:
            continue
        var rect := button.get_global_rect()
        if not rect.has_area():
            continue
        _check(rect.position.x >= -1.0 and rect.end.x <= 431.0, "Sponsor button overflows mobile width: " + button.name)
    await _capture("sponsor_offer_430x932.png")
    if failures.is_empty():
        print("PASS: sponsor offer mobile width and visible option buttons 430x932")
    else:
        printerr("FAIL: ", failures)
    quit(0 if failures.is_empty() else 1)

func _capture(filename: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var dest := OS.get_environment("TC_CAPTURE_DIR")
    if dest.is_empty():
        return
    DirAccess.make_dir_recursive_absolute(dest)
    var img := root.get_viewport().get_texture().get_image()
    _check(img.get_width() == 430 and img.get_height() == 932, "Unexpected image resolution")
    _check(img.save_png(dest.path_join(filename)) == OK, "Screenshot save failed")

func _check(ok: bool, msg: String) -> void:
    if not ok:
        failures.append(msg)
        push_error(msg)
