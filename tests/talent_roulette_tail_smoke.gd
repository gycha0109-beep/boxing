extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("Roulette Tail QA", "technician")
    game.state["first_launch_acknowledged"] = true

    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui._return_to_reference_title()
    ui._start_new_career_from_title(true)
    await process_frame

    _check(bool(game.select_boxing_style("balanced").get("ok", false)), "style selection failed")
    ui._render_phase()
    await process_frame

    var roll: Node = ui.body.get_node_or_null("FirstCycleTalentRoll")
    var strip: HBoxContainer = roll.find_child("TalentRouletteStrip", true, false) as HBoxContainer if roll != null else null
    _check(strip != null, "roulette strip missing")
    if strip != null:
        _check(strip.get_child_count() == 36, "roulette must contain 8 continuation cards")
        if strip.get_child_count() == 36:
            var chosen_id := str(game.state.get("boxer", {}).get("trait_id", ""))
            _check(str(strip.get_child(27).get_meta("talent_id", "")) == chosen_id, "winning card moved from the stop position")
            for i in range(28, 36):
                _check(str(strip.get_child(i).get_meta("talent_id", "")) != chosen_id, "winning card repeated in continuation tail")

    await create_timer(4.9).timeout
    _check(roll != null and not bool(roll.get_node("RandomTalentContinue").disabled), "roulette did not finish")

    if DisplayServer.get_name() != "headless":
        var viewport_texture := root.get_texture()
        if viewport_texture != null:
            var screenshot := viewport_texture.get_image()
            if screenshot != null:
                screenshot.save_png("res://docs/ui-audit/talent-roulette-tail-fix.png")

    if is_instance_valid(ui):
        ui.queue_free()
        await process_frame
    if failures.is_empty():
        print("PASS: winning card stays centered and 8 continuation cards hide the strip endpoint")
        quit(0)
    else:
        for failure in failures:
            printerr("FAIL: ", failure)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
