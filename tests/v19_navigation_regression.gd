extends SceneTree

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState missing")
    if not is_instance_valid(game_state):
        _finish()
        return
    game_state.new_career("Navigation QA", "technician")
    game_state.state["first_launch_acknowledged"] = true
    game_state.state["phase"] = "camp"
    var scene := load("res://scenes/Main.tscn") as PackedScene
    _check(scene != null, "Main scene missing")
    if scene == null:
        _finish()
        return
    main_view = scene.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _nonempty("camp initial")
    main_view._v17_open_shop()
    await process_frame
    _check(_phase() == "equipment_shop", "shop button did not open equipment phase")
    _nonempty("shop")

    main_view._v17_open_training()
    await process_frame
    _check(_phase() == "camp", "training did not return from equipment to camp")
    _check(str(main_view.v17_overlay).is_empty(), "training left overlay")
    _nonempty("training")

    main_view._v17_open_match()
    await process_frame
    _check(_phase() == "camp", "match mutated career phase from camp")
    _check(str(main_view.v17_overlay) == "match_blocked", "match did not explain training prerequisite")
    _nonempty("match prerequisite")
    main_view._v19_return_to_phase()

    main_view._v17_open_shop()
    await process_frame
    _check(_phase() == "equipment_shop", "shop failed after match tab")
    main_view._v17_open_match()
    await process_frame
    _check(_phase() == "equipment_shop", "match tab overwrote equipment phase")
    _check(str(main_view.v17_overlay) == "match_blocked", "match tab did not explain equipment prerequisite")
    _nonempty("match from shop")

    main_view._v17_open_training()
    await process_frame
    _check(_phase() == "camp", "training cannot recover from blocked match tab")
    _nonempty("recovered camp")
    main_view._v17_open_overlay("profile")
    await process_frame
    _nonempty("profile")
    main_view._v17_open_overlay("career")
    await process_frame
    _nonempty("career")
    main_view._v19_open_menu()
    await process_frame
    _nonempty("header menu")
    main_view._v19_close_secondary()
    await process_frame
    _check(str(main_view.v17_overlay) == "career", "closing menu did not restore career tab")
    main_view._v19_open_settings()
    await process_frame
    _nonempty("settings")
    main_view._v19_close_secondary()
    await process_frame
    _check(str(main_view.v17_overlay) == "career", "closing settings did not restore career tab")
    _check(not main_view.v19_settings_button.disabled, "visible settings button is disabled")
    _finish()

func _nonempty(where: String) -> void:
    var body: VBoxContainer = main_view.body
    _check(is_instance_valid(body) and body.get_child_count() > 0, "%s showed an empty content area" % where)

func _phase() -> String:
    return str(game_state.state.get("phase", ""))

func _check(condition: bool, issue: String) -> void:
    if not condition:
        failures.append(issue)
        push_error(issue)

func _finish() -> void:
    if failures.is_empty():
        print("PASS: v19 navigation never dead-ends in tested career phases")
        quit(0)
    else:
        printerr("FAIL: v19 navigation; ", failures)
        quit(1)
