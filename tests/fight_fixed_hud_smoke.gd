extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    _cleanup_save_files()
    await process_frame

    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState unavailable")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "fight HUD fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

    game_state.new_career("HUD Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    game_state.state["first_launch_acknowledged"] = true
    game_state.state["weigh_in_acknowledged"] = true
    game_state.state.phase = "fight_offer"
    var opponent: Dictionary = opponents[0]
    game_state.select_opponent(opponent)
    var selected: Dictionary = game_state.select_game_plan("outside_boxing")
    _check(bool(selected.get("ok", false)), "fight HUD fixture could not select plan")

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    main_view.set("current_opponent", opponent)
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    var scroll := _find_scroll(main_view)
    _check(is_instance_valid(scroll), "fight HUD has no ScrollContainer")
    if is_instance_valid(scroll):
        _check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "fight screen still allows vertical scrolling")
        _check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "fight screen allows horizontal scrolling")
        _check(scroll.scroll_vertical == 0, "fight HUD did not reset to the top")

    var stage := _find_stage(main_view)
    _check(is_instance_valid(stage), "fight HUD has no visible FightStage")
    if is_instance_valid(stage):
        _check(stage.custom_minimum_size.y >= 300.0, "fight stage is too short to remain the visual focus")

    var text := "\n".join(_collect_text(main_view))
    _check(text.contains("ROUND 1"), "fight HUD has no round header")
    _check(text.contains("RING"), "fight HUD has no ring label")
    _check(text.contains("OPPONENT READ"), "fight HUD has no compact opponent read strip")
    _check(text.contains("다음 행동"), "fight HUD has no action section")
    _check(not text.contains("상대 몸통 상태:"), "legacy long tactical copy still occupies the fight screen")

    var labels := ["잽", "강타", "바디", "가드", "카운터"]
    var buttons := _buttons_under(main_view)
    for label_text in labels:
        _check(_has_action_button(buttons, label_text), "fight HUD missing fixed action button: %s" % label_text)
    _check(buttons.size() >= 5, "fight HUD does not expose all five actions at once")

    _finish()

func _find_scroll(root: Node) -> ScrollContainer:
    for node in root.find_children("*", "ScrollContainer", true, false):
        if node is ScrollContainer:
            return node as ScrollContainer
    return null

func _find_stage(root: Node) -> FightStage:
    if root is FightStage:
        return root as FightStage
    for child in root.get_children():
        var found := _find_stage(child)
        if is_instance_valid(found):
            return found
    return null

func _buttons_under(root: Node) -> Array[Button]:
    var out: Array[Button] = []
    if root is Button:
        out.append(root as Button)
    for child in root.get_children():
        out.append_array(_buttons_under(child))
    return out

func _has_action_button(buttons: Array[Button], label_text: String) -> bool:
    for button in buttons:
        if button.text.begins_with(label_text):
            return true
    return false

func _collect_text(root: Node) -> Array[String]:
    var out: Array[String] = []
    if root is Label:
        out.append((root as Label).text)
    elif root is Button:
        out.append((root as Button).text)
    for child in root.get_children():
        out.append_array(_collect_text(child))
    return out

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Array else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("fight-fixed-hud-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
