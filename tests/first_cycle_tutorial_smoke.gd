extends SceneTree

var failures: Array[String] = []
var game_state: Node
var main_view: Control


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    game_state = get_root().get_node_or_null("GameState")
    if not is_instance_valid(game_state):
        _fail("GameState autoload is missing")
        _finish()
        return

    game_state.new_career("Tutorial Test", "technician")
    game_state.state["first_launch_acknowledged"] = true
    var scene := load("res://scenes/Main.tscn") as PackedScene
    main_view = scene.instantiate()
    get_root().add_child(main_view)
    await process_frame
    main_view._return_to_reference_title()
    main_view._start_new_career_from_title()
    await process_frame
    await process_frame
    _check(bool(game_state.state.get("first_cycle_tutorial", {}).get("active", false)), "new career did not activate tutorial")
    _coach("style_select")
    var creation: Node = main_view.body.get_node_or_null("ReferenceBoxerCreation")
    _check(creation != null, "creation view missing")
    if creation != null:
        var visible_cards := 0
        for child in creation.get_children():
            if str(child.name).begins_with("BoxerStyleCard_") and child.visible:
                visible_cards += 1
        _check(visible_cards == 1, "creation must show only one style at a time")

    _check(bool(game_state.select_boxing_style("balanced").get("ok", false)), "style selection failed")
    main_view._render_phase()
    await process_frame
    _coach("talent_reveal")
    _check(bool(game_state.confirm_talent().get("ok", false)), "talent confirmation failed")
    main_view._render_phase()
    await process_frame
    _coach("camp")
    _check(not main_view.camp_actions.is_empty(), "no camp actions")
    main_view._choose_camp_action(main_view.camp_actions[0])
    await process_frame
    _coach("fight_offer")
    var offers: Array = game_state.get_fight_offers(main_view.opponents)
    _check(not offers.is_empty(), "no opponent offers")
    if offers.is_empty():
        _finish()
        return
    main_view._accept_reference_offer(offers[0])
    await process_frame
    _coach("tactical_prep")
    _check(bool(game_state.select_tactical_preparation(str(game_state.tactical_preparations()[0]["id"])).get("ok", false)), "tactical preparation failed")
    main_view._render_phase()
    await process_frame
    _coach("condition_prep")
    _check(bool(game_state.select_condition_preparation(str(game_state.condition_preparations()[0]["id"])).get("ok", false)), "condition preparation failed")
    main_view._render_phase()
    await process_frame
    _coach("game_plan")
    main_view._choose_game_plan("balanced")
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "fight", "game plan did not enter the fight phase")
    _check(not bool(game_state.state.get("weigh_in_acknowledged", true)), "weigh-in confirmation skipped")
    main_view._acknowledge_weigh_in()
    await process_frame
    _check(main_view.body.get_node_or_null("ReferenceBattle") != null, "battle view missing")
    _check(main_view.combat != null, "combat engine missing")
    if main_view.combat == null:
        _finish()
        return
    main_view._choose_fight_action("jab")
    await process_frame
    var seen: Array = game_state.state.get("first_cycle_tutorial", {}).get("actions_seen", [])
    _check(seen.has("jab"), "real combat action was not recorded")
    for i in range(50):
        if bool(main_view.combat.snapshot().get("finished", false)):
            break
        main_view.combat.resolve_exchange("guard")
    main_view._render_fight()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "result", "fight did not reach result")
    if str(game_state.state.get("phase", "")) == "result":
        main_view._render_phase()
        await process_frame
        _coach("result")
        main_view._continue_from_reference_result()
        await process_frame
        var tutorial: Dictionary = game_state.state.get("first_cycle_tutorial", {})
        _check(bool(tutorial.get("complete", false)), "tutorial not marked completed after settlement")
        _check(not bool(tutorial.get("active", true)), "tutorial still active after settlement")
    _finish()


func _coach(expected_phase: String) -> void:
    _check(str(game_state.state.get("phase", "")) == expected_phase, "wrong phase, expected " + expected_phase)
    _check(main_view.body.get_node_or_null("FirstCycleCoach") != null, "missing coach in " + expected_phase)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    failures.append(message)
    push_error(message)


func _finish() -> void:
    if failures.is_empty():
        print("PASS: first-cycle tutorial traverses creation, training, preparation, fight and settlement")
        quit(0)
    else:
        printerr("FAIL: first-cycle tutorial: ", failures)
        quit(1)
