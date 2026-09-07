extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    await process_frame
    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState autoload was not available")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "fight UI fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

    game_state.new_career("UI 복서", "technician")
    game_state.state.boxer.weight_kg = 61.0
    game_state.state.phase = "fight_offer"
    var opponent: Dictionary = opponents[0]
    game_state.select_opponent(opponent)
    var selected: Dictionary = game_state.select_game_plan("outside_boxing")
    _check(bool(selected.get("ok", false)), "fight UI fixture could not select game plan")
    _check(str(game_state.state.phase) == "fight", "fight UI fixture did not enter fight phase")

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load after autoload initialization")
    if not is_instance_valid(packed):
        _finish()
        return
    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    var initial_text: String = "\n".join(_collect_text(main_view))
    _check(initial_text.contains("ROUND 1"), "fight UI missing round header")
    _check(initial_text.contains("RING"), "fight UI missing ring card")
    _check(initial_text.contains("OPPONENT READ"), "fight UI missing opponent read card")
    _check(initial_text.contains(str(opponent.name)), "fight UI missing opponent name")
    _check(initial_text.contains("HP"), "fight UI missing HP gauge labels")
    _check(initial_text.contains("STA"), "fight UI missing stamina gauge labels")

    var button_texts: Array[String] = _collect_button_text(main_view)
    for action_label in ["잽", "강타", "바디", "가드", "카운터"]:
        _check(_contains_button_label(button_texts, action_label), "fight UI missing action button: %s" % action_label)

    var locked_action: String = str(game_state.state.get("active_fight", {}).get("pending_opponent_action", ""))
    _check(not locked_action.is_empty(), "rendered telegraph did not persist locked opponent action")
    _check(not game_state.state.get("active_fight", {}).get("pending_telegraph", {}).is_empty(), "rendered telegraph did not persist save payload")

    main_view._choose_fight_action("jab")
    await process_frame
    await process_frame

    var saved_fight: Dictionary = game_state.state.get("active_fight", {})
    var last_exchange: Dictionary = saved_fight.get("last_exchange", {})
    _check(not last_exchange.is_empty(), "fight UI action did not persist structured exchange result")
    _check(str(last_exchange.get("player_action", "")) == "jab", "fight UI action persisted wrong player action")
    _check(str(last_exchange.get("opponent_action", "")) == locked_action, "fight UI action did not consume locked telegraph action")

    var after_text: String = "\n".join(_collect_text(main_view))
    _check(after_text.contains("OPPONENT READ"), "fight UI did not render next opponent read after exchange")
    _check(after_text.contains("다음 행동"), "fight UI lost action decision section after exchange")
    _finish()

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("v04-fight-ui-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _collect_text(root: Node) -> Array[String]:
    var output: Array[String] = []
    if root is Label:
        output.append(str(root.text))
    elif root is Button:
        output.append(str(root.text))
    for child in root.get_children():
        output.append_array(_collect_text(child))
    return output

func _collect_button_text(root: Node) -> Array[String]:
    var output: Array[String] = []
    if root is Button:
        output.append(str(root.text))
    for child in root.get_children():
        output.append_array(_collect_button_text(child))
    return output

func _contains_button_label(button_texts: Array[String], label_text: String) -> bool:
    for text in button_texts:
        if str(text).begins_with(label_text):
            return true
    return false

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
