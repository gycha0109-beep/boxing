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
    main_view._onboarding_install.clear()
    main_view._guide_settings.clear()
    main_view._return_to_reference_title()
    main_view._start_new_career_from_title()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "tutorial_welcome", "welcome screen missing")
    _check(main_view.body.get_node_or_null("FirstCycleStory") != null, "welcome presentation missing")
    main_view._tutorial_story_next()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "tutorial_overview", "overview missing")
    main_view._tutorial_story_next()
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
        _check(visible_cards == game_state.boxing_styles().size(), "all existing styles must be visible")

    _check(bool(game_state.select_boxing_style("balanced").get("ok", false)), "style selection failed")
    main_view._render_phase()
    await process_frame
    _coach("talent_reveal")
    var roll: Node = main_view.body.get_node_or_null("FirstCycleTalentRoll")
    _check(roll != null, "random talent draw screen missing")
    var reel: Node = roll.find_child("TalentRouletteViewport", true, false) if roll != null else null
    var strip: Node = roll.find_child("TalentRouletteStrip", true, false) if roll != null else null
    _check(reel != null, "visible roulette reel missing")
    _check(strip != null and strip.get_child_count() == 28, "roulette cards missing")
    var shown_talents: Dictionary = {}
    var icon_count := 0
    if strip != null:
        for card in strip.get_children():
            shown_talents[str(card.get_meta("talent_id", ""))] = true
            var card_content: Node = card.get_child(0) if card.get_child_count() > 0 else null
            var icon: TextureRect = card_content.get_child(0) as TextureRect if card_content != null and card_content.get_child_count() > 0 else null
            if icon != null and icon.texture != null:
                icon_count += 1
    _check(shown_talents.size() == game_state.talent_options().size(), "roulette does not show every talent type")
    _check(icon_count == 28, "one or more roulette talent icons are missing")
    var assigned_id := str(game_state.state.get("boxer", {}).get("trait_id", ""))
    _check(not assigned_id.is_empty(), "random talent not assigned")
    if strip != null and strip.get_child_count() == 28:
        _check(str(strip.get_child(27).get_meta("talent_id", "")) == assigned_id, "roulette target does not match the assigned talent")
    _check(bool(roll.get_node("RandomTalentContinue").disabled), "roulette button must remain locked during spin")
    await create_timer(4.9).timeout
    _check(not bool(roll.get_node("RandomTalentContinue").disabled), "roulette did not finish and unlock result")
    var result_name: Node = roll.find_child("TalentResultName", true, false)
    _check(result_name != null and str(result_name.text) == str(game_state.state.get("boxer", {}).get("trait_name", "")), "roulette stopped on a different talent")
    main_view._complete_random_talent_roll()
    await process_frame
    _check(bool(game_state.state.get("first_cycle_tutorial", {}).get("talent_roll_seen", false)), "talent reveal not recorded")
    _check(str(game_state.state.get("boxer", {}).get("trait_id", "")) == assigned_id, "talent changed during visual draw")
    var reveal: Node = main_view.body.get_node_or_null("ReferenceBoxerCreation")
    _check(reveal != null and not bool(reveal.get("choosing_talent")), "talent result missing")
    _check(reveal.get_node_or_null("BoxerReselectTalent") == null, "talent selection still available")
    main_view._confirm_talent()
    await process_frame
    _coach("camp")
    _check(not main_view.camp_actions.is_empty(), "no camp actions")
    main_view._choose_camp_action(main_view.camp_actions[0])
    await process_frame
    _check(main_view.body.get_node_or_null("FirstCycleStory") != null, "training result screen missing")
    main_view._tutorial_story_next()
    await process_frame
    _coach("fight_offer")
    var offers: Array = game_state.get_fight_offers(main_view.opponents)
    _check(not offers.is_empty(), "no opponent offers")
    if offers.is_empty():
        _finish()
        return
    var offer_view: Node = main_view.body.get_node_or_null("ReferenceFightOffers")
    var offer_id := str(offers[0].get("id", ""))
    var offer_accept: Button = offer_view.find_child("FightOfferSelect_" + offer_id, true, false) as Button
    var offer_analyze: Button = offer_view.find_child("FightOfferAnalyze_" + offer_id, true, false) as Button
    _check(offer_accept != null and offer_accept.disabled, "guided contract must require opponent analysis")
    _check(offer_analyze != null, "opponent analysis button missing")
    offer_analyze.pressed.emit()
    _check(not offer_accept.disabled, "opponent selection did not unlock after analysis")
    offer_accept.pressed.emit()
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
    _check(main_view.combat.tutorial_first_bout, "first bout victory protection was not enabled")
    _check(main_view._tutorial_next_action() == "jab", "first fight guide should begin with jab")
    main_view._choose_fight_action("guard")
    await process_frame
    var seen: Array = game_state.state.get("first_cycle_tutorial", {}).get("actions_seen", [])
    _check(seen.has("guard"), "real combat action was not recorded")
    _check(main_view._tutorial_next_action() == "jab", "guidance must keep the unused jab highlighted")
    var fight_view: Node = main_view.body.get_node_or_null("ReferenceBattle")
    if fight_view != null:
        _check(str(fight_view.get("tutorial_target_action")) == "jab", "jab guidance disappeared before jab was used")
    for i in range(60):
        if not main_view.fight_input_locked:
            break
        await process_frame
    main_view._choose_fight_action("jab")
    await process_frame
    _check(main_view._tutorial_next_action() == "counter", "guidance must advance to the unused counter")
    for i in range(60):
        if not main_view.fight_input_locked:
            break
        await process_frame
    main_view._choose_fight_action("counter")
    await process_frame
    _check(main_view._tutorial_next_action().is_empty(), "jab, guard and counter should complete the action guide")
    var actual_actions: Array = game_state.state.get("first_cycle_tutorial", {}).get("actions_seen", [])
    _check(actual_actions.has("jab") and actual_actions.has("guard") and actual_actions.has("counter"), "all three real fight actions must be recorded")
    var saved := SaveService.load_game()
    var checkpoint: Dictionary = saved.active_fight
    _check(int(checkpoint.exchange_no) > 0 and not str(checkpoint.pending_opponent_action).is_empty(), "mid-fight checkpoint")
    game_state.state = saved
    main_view.combat = null
    main_view.current_opponent = {}
    main_view._start_fight()
    var resumed: Dictionary = main_view.combat.export_state()
    for key in ["round_no", "exchange_no", "player_hp", "opponent_hp", "player_stamina", "opponent_stamina"]:
        _check(is_equal_approx(float(checkpoint[key]), float(resumed[key])), "resumed " + key)
    _check(resumed.rng_state == checkpoint.rng_state and resumed.pending_opponent_action == checkpoint.pending_opponent_action, "restored the same pending exchange")
    for i in range(50):
        if bool(main_view.combat.snapshot().get("finished", false)):
            break
        main_view.combat.resolve_exchange("guard")
    main_view._render_fight()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "result", "fight did not reach result")
    _check(str(game_state.state.get("last_result", "")).begins_with("WIN"), "guided first bout must end in victory")
    if str(game_state.state.get("phase", "")) == "result":
        main_view._render_phase()
        await process_frame
        _coach("result")
        main_view._continue_from_reference_result()
        await process_frame
        _check(main_view.body.get_node_or_null("FirstCycleStory") != null, "tutorial completion screen missing")
        main_view._tutorial_story_next()
        await process_frame
        var tutorial: Dictionary = game_state.state.get("first_cycle_tutorial", {})
        _check(bool(tutorial.get("complete", false)), "tutorial not marked completed after settlement")
        _check(not bool(tutorial.get("active", true)), "tutorial still active after settlement")
    _finish()


func _coach(expected_phase: String) -> void:
    _check(str(game_state.state.get("phase", "")) == expected_phase, "wrong phase, expected " + expected_phase)
    if expected_phase == "talent_reveal":
        _check(main_view.body.get_node_or_null("FirstCycleTalentRoll") != null, "missing dedicated talent roulette")
        return
    _check(main_view.get_node_or_null("FirstCycleSpotlight") != null or expected_phase in ["fight_offer", "tactical_prep", "condition_prep", "game_plan"], "missing phase-specific coaching in " + expected_phase)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    failures.append(message)
    push_error(message)


func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
        await process_frame
        main_view = null
    await create_timer(0.15).timeout
    if failures.is_empty():
        print("PASS: first-cycle tutorial traverses creation, training, preparation, fight and settlement")
        quit(0)
    else:
        printerr("FAIL: first-cycle tutorial: ", failures)
        quit(1)
