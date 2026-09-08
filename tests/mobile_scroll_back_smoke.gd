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
    _check(not opponents.is_empty(), "mobile UX fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

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
        _check(not buttons.is_empty(), "game-plan screen rendered no buttons")
        for button in buttons:
            _check(button.mouse_filter == Control.MOUSE_FILTER_PASS, "button blocks parent touch drag: %s" % button.text)

    _check_fighter_profile("game-plan")

    var back_button := _button_with_text(main_view, "← 상대 다시 선택")
    _check(is_instance_valid(back_button), "game-plan screen has no opponent back button")

    main_view._return_to_fight_offers()
    await process_frame
    _check(str(game_state.state.get("phase", "")) == "fight_offer", "opponent back navigation did not return to fight offers")
    _check(str(game_state.state.get("selected_opponent", "")).is_empty(), "opponent back navigation did not clear selected opponent")
    _check(str(game_state.state.get("selected_game_plan", "")).is_empty(), "opponent back navigation did not clear selected game plan")

    scroll = _find_scroll(main_view)
    if is_instance_valid(scroll):
        for button in _buttons_under(scroll):
            _check(button.mouse_filter == Control.MOUSE_FILTER_PASS, "fight-offer button blocks parent touch drag after rerender: %s" % button.text)

    _check_fighter_profile("fight-offer")
    _finish()

func _check_fighter_profile(context: String) -> void:
    var text := "\n".join(_collect_text(main_view))
    _check(text.contains("내 복서 · MY BOXER"), "%s screen has no clear fighter profile heading" % context)
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
