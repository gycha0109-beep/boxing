extends SceneTree

var failures: Array[String] = []
var game: Node
var screen: Control


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: use an isolated user-data directory")
        quit(2)
        return
    game = root.get_node("GameState")
    game.new_career("Guide Skip QA", "technician")
    game.state["first_launch_acknowledged"] = true
    screen = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(screen)
    await process_frame
    screen._onboarding_install.clear()
    screen._guide_settings.clear()
    screen._return_to_reference_title()
    screen._start_new_career_from_title(true)
    await process_frame

    _check(str(game.state.get("phase", "")) == "style_select", "tutorial must begin in boxer creation")
    _check(screen.body.get_node_or_null("ReferenceBoxerCreation") != null, "boxer creation missing before tutorial skip")
    _press_skip()
    await process_frame
    _check(str(game.state.get("phase", "")) == "style_select", "skip must preserve boxer creation")
    _check(not screen._tutorial_active(), "skip left guide active")
    _check(not bool(SaveService.load_game().get("first_cycle_tutorial", {}).get("active", true)), "skip was not saved")

    # Test skipping while a randomly assigned talent reel is still spinning.
    screen._set_first_bout_guide(true)
    screen._onboarding_install.clear()
    screen._return_to_reference_title()
    screen._start_new_career_from_title(true)
    await process_frame
    _check(bool(game.select_boxing_style("balanced").get("ok", false)), "style selection failed")
    screen._render_phase()
    await process_frame
    var original_trait := str(game.state.get("boxer", {}).get("trait_id", ""))
    _check(screen.body.get_node_or_null("FirstCycleTalentRoll") != null, "talent reel was not shown")
    _press_skip()
    await process_frame
    _check(str(game.state.get("phase", "")) == "talent_reveal", "skip from reel must preserve creation phase")
    _check(str(game.state.get("boxer", {}).get("trait_id", "")) == original_trait, "skip from reel changed the random talent")
    _check(screen.body.get_node_or_null("FirstCycleTalentRoll") == null, "skipped reel remained visible")
    _check(screen.body.get_node_or_null("ReferenceBoxerCreation") != null, "skip from reel did not open regular talent result")
    screen._confirm_talent()
    await process_frame
    _check(str(game.state.get("phase", "")) == "camp", "skip from reel blocked first camp")

    # A skipped intermediate training result must never repeat its effects.
    screen._set_first_bout_guide(true)
    var tutorial: Dictionary = game.state.get("first_cycle_tutorial", {}).duplicate(true)
    tutorial["active"] = true
    tutorial["complete"] = false
    game.state["first_cycle_tutorial"] = tutorial
    SaveService.save_game(game.state)
    var fights_before: int = int(game.state.get("career", {}).get("fights", 0))
    screen._choose_camp_action(screen.camp_actions[0])
    await process_frame
    _check(bool(game.state.get("first_cycle_tutorial", {}).get("training_result_pending", false)), "training result step missing")
    _press_skip()
    await process_frame
    _check(str(game.state.get("phase", "")) == "fight_offer", "skip from training result did not preserve fight offers")
    _check(int(game.state.get("career", {}).get("fights", 0)) == fights_before, "skip incorrectly settled a fight")
    _check(not bool(SaveService.load_game().get("first_cycle_tutorial", {}).get("training_result_pending", false)), "pending tutorial result survived skip")
    _check(screen.body.get_node_or_null("ReferenceFightOffers") != null, "ordinary offers did not resume")

    # Offer-level skip must unlock normal matchmaking rather than changing the career.
    screen._set_first_bout_guide(true)
    tutorial = game.state.get("first_cycle_tutorial", {}).duplicate(true)
    tutorial["active"] = true
    tutorial["complete"] = false
    game.state["first_cycle_tutorial"] = tutorial
    SaveService.save_game(game.state)
    screen._render_phase()
    await process_frame
    _press_skip()
    await process_frame
    _check(str(game.state.get("phase", "")) == "fight_offer", "offer skip changed the saved career phase")
    _check(not screen._tutorial_active(), "offer skip did not disable the guide")
    var offer: Control = screen.body.get_node_or_null("ReferenceFightOffers")
    _check(offer != null, "offer board disappeared after skip")
    if offer != null:
        var buttons := offer.find_children("FightOfferSelect_*", "Button", true, false)
        _check(not buttons.is_empty(), "no offer to select after skip")
        for item in buttons:
            _check(not (item as Button).disabled, "matchmaking stayed tutorial-locked after skip")

    screen.queue_free()
    await process_frame
    screen = null
    await create_timer(0.2).timeout
    if failures.is_empty():
        print("PASS: tutorial skip and persistence at boxer creation, reel, training and offers")
        quit(0)
    else:
        printerr("FAIL: tutorial skip: ", failures)
        quit(1)


func _press_skip() -> void:
    var button := screen.find_child("TutorialSkip", true, false) as Button
    if button == null:
        button = screen.body.find_child("TutorialSkip", true, false) as Button
    _check(button != null, "tutorial skip button missing in current view")
    if button != null:
        button.pressed.emit()


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)
