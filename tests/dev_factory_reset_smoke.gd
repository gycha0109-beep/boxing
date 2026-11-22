extends SceneTree

var errors: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    ProjectSettings.set_setting("application/config/dev_reset_enabled", false)
    if OS.has_feature("tc_dev_preview"):
        printerr("TEST MISCONFIGURED: running as preview build")
        quit(2)
        return
    ProjectSettings.set_setting("application/config/dev_reset_enabled", true)
    var game: Node = root.get_node("GameState")
    var scene: PackedScene = load("res://scenes/Main.tscn")
    var main: Control = scene.instantiate()
    root.add_child(main)
    await process_frame
    main._onboarding_install.clear()
    main._guide_settings.set_value("tutorial", "enabled", true)
    main._return_to_reference_title()
    main._start_new_career_from_title()
    await process_frame
    check(str(game.state.get("phase", "")) == "tutorial_welcome", "fresh install must show first tutorial")
    check(bool(main._onboarding_install.get_value("install", "tutorial_started", false)), "first-install marker not stored")
    check(main.body.get_node_or_null("FirstCycleStory") != null, "welcome screen missing")
    check(main.get_node_or_null("TutorialRestartButton") == null, "obsolete tutorial restart button still exists")
    game.state["career"]["wins"] = 8
    game.state["career"]["money"] = 777777
    game.state["first_cycle_tutorial"]["active"] = false
    main._return_to_reference_title()
    main._start_new_career_from_title()
    await process_frame
    check(str(game.state.get("phase", "")) == "style_select", "second new career should not show tutorial")
    check(not bool(game.state.get("first_cycle_tutorial", {}).get("active", true)), "second new career has active tutorial")
    check(int(game.state["career"]["wins"]) == 0, "new career did not clear wins")
    game.state["career"]["wins"] = 6
    game.state["career"]["money"] = 321
    main._v19_open_settings()
    await process_frame
    check(main.body.find_child("DevFactoryResetButton", true, false) != null, "dev reset button missing in Settings")
    main._confirm_dev_factory_reset()
    await process_frame
    check(str(game.state.get("phase", "")) == "tutorial_welcome", "developer reset did not restart tutorial")
    check(int(game.state["career"]["wins"]) == 0 and int(game.state["career"]["money"]) == 120000, "factory reset did not clear saved progress")
    check(bool(game.state.get("first_cycle_tutorial", {}).get("active", false)), "factory reset did not re-enable first-install tutorial")
    check(SaveService.load_game().get("phase", "") == "tutorial_welcome", "factory reset not persisted")
    main.queue_free()
    await process_frame
    await create_timer(0.15).timeout
    if errors.is_empty():
        print("PASS: first-install-only tutorial, new career no tutorial, dev factory reset works")
        quit(0)
    else:
        for e in errors:
            printerr(e)
        quit(1)

func check(valid: bool, message: String) -> void:
    if not valid:
        errors.append(message)
