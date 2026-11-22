extends SceneTree

var failures: Array[String] = []
var screen: Control

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        push_error("Use isolated user data")
        quit(2)
        return
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("Mobile Roulette QA", "technician")
    game.state["first_launch_acknowledged"] = true
    screen = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(screen)
    await process_frame
    screen._onboarding_install.clear()
    screen._guide_settings.clear()
    screen._return_to_reference_title()
    screen._start_new_career_from_title()
    await process_frame
    screen._tutorial_story_next()
    screen._tutorial_story_next()
    await process_frame
    _check(bool(game.select_boxing_style("balanced").get("ok", false)), "style selection")
    screen._render_phase()
    await process_frame
    await process_frame
    var roll: Node = screen.body.get_node_or_null("FirstCycleTalentRoll")
    _check(roll != null, "missing roulette screen")
    if roll == null:
        quit(1)
        return
    var reel := roll.find_child("TalentRouletteViewport", true, false) as Control
    var skip := roll.find_child("TutorialSkip", true, false) as Button
    var continue_btn := roll.find_child("RandomTalentContinue", true, false) as Button
    _check(reel != null and reel.size.x > 100, "roulette layout width")
    _check(skip != null and skip.is_visible_in_tree(), "skip must be visible")
    _check(continue_btn != null and continue_btn.disabled, "locked while spinning")
    await _capture("roulette_spinning_430x932.png")
    await create_timer(4.9).timeout
    _check(not continue_btn.disabled, "roulette did not unlock")
    var assigned := str(game.state.get("boxer", {}).get("trait_name", ""))
    var result := roll.find_child("TalentResultName", true, false) as Label
    _check(result != null and result.text == assigned, "assigned talent mismatch")
    var scroll := screen.find_child("V17ContentScroll", true, false) as ScrollContainer
    _check(scroll != null, "screen scroll missing")
    if scroll != null:
        for btn in [skip, continue_btn]:
            _check(btn.get_global_rect().position.x >= 0 and btn.get_global_rect().end.x <= 430, "button outside horizontal viewport")
    await _capture("roulette_result_430x932.png")
    if failures.is_empty():
        print("PASS: mobile roulette rendering and correct talent after spin, 430x932")
    else:
        printerr("FAIL: ", failures)
    quit(0 if failures.is_empty() else 1)

func _capture(filename: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var dir := OS.get_environment("TC_CAPTURE_DIR")
    if dir.is_empty():
        return
    DirAccess.make_dir_recursive_absolute(dir)
    var img := root.get_viewport().get_texture().get_image()
    _check(img.get_width() == 430 and img.get_height() == 932, "viewport resolution")
    _check(img.save_png(dir.path_join(filename)) == OK, "capture failure")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
