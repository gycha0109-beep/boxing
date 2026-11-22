extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        quit(2)
        return
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("Gym Fund Screen", "workhorse")
    game.state.career.fights = 3
    game.state.phase = "camp"
    game.state.first_launch_acknowledged = true
    game._maybe_award_gym_fund()
    _check(game.state.phase == "gym_fund_intro", "fund must interrupt camp after third fight")
    SaveService.save_game(game.state)

    var screen := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(screen)
    await process_frame
    screen.launch_gate_active = false
    screen.v17_overlay = ""
    screen._render_phase()
    await process_frame
    await process_frame
    var open_button := screen.find_child("GymFundOpenShop*", true, false) as Button
    var skip_button := screen.find_child("GymFundSkipShop*", true, false) as Button
    _check(open_button != null and skip_button != null, "fund screen lacks shop/skip choice")
    for btn in [open_button, skip_button]:
        if btn == null:
            continue
        var bounds: Rect2 = (btn as Button).get_global_rect()
        _check(bounds.position.x >= -1 and bounds.end.x <= 431, "fund button does not fit phone width")
    await _capture("gym_fund_430x932.png")
    if open_button != null:
        open_button.pressed.emit()
    await process_frame
    await process_frame
    _check(game.state.phase == "equipment_shop", "shop option must enter actual store")
    _check(bool(game.state.career_state.get("gym_fund_shop_active", false)), "shop guide marker missing")
    await _capture("gym_fund_shop_430x932.png")
    screen._return_from_equipment_shop()
    await process_frame
    _check(game.state.phase == "camp", "shop exit must resume normal camp")
    _check(not bool(game.state.career_state.get("gym_fund_shop_active", false)), "shop guide marker remains stuck")
    _check(int(game.state.career.money) == 145000, "visit to shop must not spend money")
    if failures.is_empty():
        print("PASS: third-bout fund 430x932, store tutorial, optional return, untouched wallet")
    else:
        printerr("FAIL: ", failures)
    quit(0 if failures.is_empty() else 1)

func _capture(filename: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var directory := OS.get_environment("TC_CAPTURE_DIR")
    if directory.is_empty():
        return
    DirAccess.make_dir_recursive_absolute(directory)
    var img := root.get_viewport().get_texture().get_image()
    _check(img.get_width() == 430 and img.get_height() == 932, "wrong screenshot size")
    _check(img.save_png(directory.path_join(filename)) == OK, "could not save screenshot")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
