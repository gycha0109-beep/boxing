extends SceneTree

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState autoload unavailable")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    var camps: Array = _load_array("res://data/camp_actions.json")
    _check(not opponents.is_empty(), "mobile UX fixture has no opponents")
    _check(not camps.is_empty(), "mobile UX fixture has no camp actions")
    if opponents.is_empty() or camps.is_empty():
        _finish()
        return

    var speed_routes := 0
    var max_speed_gain := 0
    for action_value in camps:
        var action: Dictionary = action_value
        var speed_gain := int(action.get("effects", {}).get("speed", 0))
        if speed_gain >= 2:
            speed_routes += 1
        max_speed_gain = max(max_speed_gain, speed_gain)
    _check(max_speed_gain >= 3, "speed training still has no primary +3 route")
    _check(speed_routes >= 3, "speed training does not offer enough meaningful routes")

    game_state.new_career("Touch Boxer", "technician")
    game_state.state["first_launch_acknowledged"] = true
    game_state.state["weigh_in_acknowledged"] = true
    game_state.state["phase"] = "fight_offer"
    game_state.select_opponent(opponents[0])

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load for mobile UX smoke")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    var scroll := _find_scroll(main_view)
    _check(is_instance_valid(scroll), "mobile UI has no ScrollContainer")
    if is_instance_valid(scroll):
        _check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "horizontal scrolling is not disabled")
        _check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "vertical touch scrolling is not automatic")
        _check(scroll.scroll_deadzone <= 8, "touch scroll deadzone is too large")
        var buttons := _buttons_under(scroll)
        _check(not buttons.is_empty(), "tactical preparation screen rendered no buttons")
        for button in buttons:
            _check(button.mouse_filter == Control.MOUSE_FILTER_PASS, "button blocks parent touch drag: %s" % button.text)

    var tactical_text := "\n".join(_collect_text(main_view))
    _check(tactical_text.contains("FIGHT CAMP · TACTICAL PREP"), "opponent selection did not render tactical preparation")
    _check(tactical_text.contains("영구 스탯은 더 오르지 않습니다"), "tactical preparation hides the one-growth rule")
    _check_fighter_profile("tactical-prep")

    for plan_value in game_state.game_plans:
        var plan: Dictionary = plan_value
        var visible_effect := str(main_view._plan_effect_text(plan))
        _check(not visible_effect.contains("%"), "game-plan UI exposes internal percent: %s" % visible_effect)
        _check(not visible_effect.contains("파워+") and not visible_effect.contains("스피드+") and not visible_effect.contains("테크닉+"), "game-plan UI exposes internal stat modifier: %s" % visible_effect)
    var tendency_text := str(main_view._tendency_text(opponents[0].get("tendencies", {})))
    _check(not tendency_text.contains("%"), "scouting tendency still exposes internal probability")

    var opponent_back := _button_with_text(main_view, "← 상대 다시 선택")
    _check(is_instance_valid(opponent_back), "tactical preparation has no opponent back button")
    main_view._return_from_tactical_to_offers()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "fight_offer", "opponent back navigation did not return to fight offers")
    _check(str(game_state.state.get("selected_opponent", "")).is_empty(), "opponent back navigation did not clear selected opponent")
    _check(str(game_state.state.get("selected_tactical_prep", "")).is_empty(), "opponent back navigation did not clear tactical preparation")

    scroll = _find_scroll(main_view)
    if is_instance_valid(scroll):
        for button in _buttons_under(scroll):
            _check(button.mouse_filter == Control.MOUSE_FILTER_PASS, "fight-offer button blocks parent touch drag after rerender: %s" % button.text)
    _check_fighter_profile("fight-offer")

    var limit := float(game_state.career_balance.weight_class.limit_kg)
    var soft_over := float(game_state.career_balance.weigh_in.soft_over_kg)
    var test_over := 0.05
    if soft_over > 0.0:
        test_over = max(0.01, soft_over * 0.5)
    game_state.state.boxer.weight_kg = limit + test_over
    game_state.state.boxer.fatigue = 17
    game_state.state.boxer.health = 91
    game_state.state.career.reputation = 6
    var before_weight := float(game_state.state.boxer.weight_kg)
    var before_fatigue := int(game_state.state.boxer.fatigue)
    var before_health := int(game_state.state.boxer.health)
    var before_reputation := int(game_state.state.career.reputation)

    game_state.select_opponent(opponents[0])
    main_view.current_opponent = opponents[0]
    main_view._render_phase()
    await process_frame
    main_view._choose_tactical_preparation("distance_drill")
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "condition_prep", "tactical choice did not advance to condition preparation")
    _check(is_instance_valid(_button_with_text(main_view, "← 전술 준비 다시 선택")), "condition screen has no tactical back button")
    _check_fighter_profile("condition-prep")

    main_view._choose_condition_preparation("sharpness")
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "game_plan", "condition choice did not advance to game plan")
    _check(is_instance_valid(_button_with_text(main_view, "← 컨디션 다시 선택")), "game-plan screen has no condition back button")
    _check(is_instance_valid(_button_with_text(main_view, "← 상대 다시 선택")), "game-plan screen has no opponent back button")
    _check_fighter_profile("game-plan")

    main_view._choose_game_plan("outside_boxing")
    await process_frame
    await process_frame

    _check(str(game_state.state.get("phase", "")) == "fight", "game plan selection did not advance to fight/weigh-in")
    _check(not game_state.state.get("pre_game_plan_snapshot", {}).is_empty(), "game plan selection did not persist rollback snapshot")
    var plan_back_button := _button_with_text(main_view, "← 게임플랜 다시 선택")
    _check(is_instance_valid(plan_back_button), "weigh-in screen has no game-plan back button")

    main_view._return_to_game_plan_selection()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "game_plan", "game-plan back navigation did not return to scouting")
    _check(str(game_state.state.get("selected_game_plan", "")).is_empty(), "game-plan back navigation did not clear selected plan")
    _check(str(game_state.state.get("selected_tactical_prep", "")) == "distance_drill", "game-plan back lost tactical preparation")
    _check(str(game_state.state.get("selected_condition_prep", "")) == "sharpness", "game-plan back lost condition preparation")
    _check(game_state.state.get("last_weigh_in", {}).is_empty(), "game-plan back navigation did not clear resolved weigh-in")
    _check(game_state.state.get("pre_game_plan_snapshot", {}).is_empty(), "game-plan rollback snapshot was not consumed")
    _check(abs(float(game_state.state.boxer.weight_kg) - before_weight) < 0.001, "game-plan back did not restore pre-weigh-in weight")
    _check(int(game_state.state.boxer.fatigue) == before_fatigue, "game-plan back did not restore pre-weigh-in fatigue")
    _check(int(game_state.state.boxer.health) == before_health, "game-plan back did not restore pre-weigh-in health")
    _check(int(game_state.state.career.reputation) == before_reputation, "game-plan back did not restore pre-weigh-in reputation")

    main_view._return_to_condition_preparation()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "condition_prep", "condition back did not return from game plan")
    _check(str(game_state.state.get("selected_condition_prep", "")).is_empty(), "condition back did not clear condition choice")
    _check(str(game_state.state.get("selected_tactical_prep", "")) == "distance_drill", "condition back unexpectedly cleared tactical choice")

    _finish()

func _check_fighter_profile(context: String) -> void:
    var text := "\n".join(_collect_text(main_view))
    _check(text.contains("내 복서 · YOUR FIGHTER"), "%s screen has no clear fighter profile heading" % context)
    _check(text.contains("Touch Boxer"), "%s fighter profile is missing boxer name" % context)
    for stat_label in ["파워", "스피드", "테크닉", "수비", "컨디셔닝"]:
        _check(text.contains(stat_label), "%s fighter profile is missing stat label: %s" % [context, stat_label])
    _check(text.contains("현재 상태"), "%s fighter profile is missing condition summary" % context)
    _check(text.contains("복싱 정체성"), "%s fighter profile is missing identity explanation" % context)

    var profile_bars := 0
    for node in main_view.find_children("*", "ProgressBar", true, false):
        if node is ProgressBar:
            profile_bars += 1
    _check(profile_bars >= 5, "%s fighter profile did not render five readable stat bars" % context)

func _find_scroll(root: Node) -> ScrollContainer:
    for node in root.find_children("*", "ScrollContainer", true, false):
        if node is ScrollContainer:
            return node as ScrollContainer
    return null

func _buttons_under(root: Node) -> Array[Button]:
    var result: Array[Button] = []
    for node in root.find_children("*", "Button", true, false):
        if node is Button:
            result.append(node as Button)
    return result

func _button_with_text(root: Node, text_value: String) -> Button:
    for button in _buttons_under(root):
        if button.text == text_value:
            return button
    return null

func _collect_text(root: Node) -> Array[String]:
    var values: Array[String] = []
    if root is Label:
        values.append((root as Label).text)
    elif root is Button:
        values.append((root as Button).text)
    for child in root.get_children():
        values.append_array(_collect_text(child))
    return values

func _load_array(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return []
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    if failures.is_empty():
        print("mobile-scroll-back-profile-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
