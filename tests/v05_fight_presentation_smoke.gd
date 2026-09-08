extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")
const Impact = preload("res://scripts/ui/impact_feedback.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_impact_profiles()
    _cleanup_save_files()
    await process_frame

    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState autoload was not available")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "v0.5 fight fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

    game_state.new_career("Presentation Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    # Presentation QA must not depend on a random first-exchange KO. Keep both
    # sides below the damage threshold used by CombatEngine's chance-based KO
    # check and force the opponent to guard for this single presentation probe.
    game_state.state.boxer.power = 1
    game_state.state.boxer.technique = 1
    game_state.state.boxer.defense = 100
    game_state.state.boxer.conditioning = 100
    game_state.state.phase = "fight_offer"
    var opponent: Dictionary = opponents[0].duplicate(true)
    opponent.stats.power = 1
    opponent.stats.technique = 1
    opponent.tendencies = {
        "jab": 0.0,
        "power": 0.0,
        "body": 0.0,
        "guard": 1.0,
        "counter": 0.0
    }
    game_state.select_opponent(opponent)
    _check(bool(game_state.select_tactical_preparation("counter_timing").get("ok", false)), "v0.5 fixture could not select tactical preparation")
    _check(bool(game_state.select_condition_preparation("sharpness").get("ok", false)), "v0.5 fixture could not select condition preparation")
    var selected: Dictionary = game_state.select_game_plan("counter_trap")
    _check(bool(selected.get("ok", false)), "v0.5 fixture could not select game plan")
    _check(str(game_state.state.phase) == "fight", "v0.5 fixture did not enter fight phase")
    game_state.state.fight_seed = 1

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load for v0.5")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    main_view.set("current_opponent", opponent)
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    var initial_stage: Node = _find_named(main_view, "FightStage")
    _check(is_instance_valid(initial_stage), "fight stage was not rendered")
    if is_instance_valid(initial_stage):
        _check(float(initial_stage.custom_minimum_size.y) >= 240.0, "fight stage is too short for portrait presentation")
        _check(str(initial_stage.get("last_animation_profile")) == "idle", "initial fight stage should be idle")
        var pending: Dictionary = game_state.state.get("active_fight", {})
        var pending_read: Dictionary = pending.get("pending_telegraph", {})
        _check(str(initial_stage.get("telegraph_action")) == str(pending_read.get("action_id", "")), "stage telegraph does not match saved opponent read")

    var locked_action: String = str(game_state.state.get("active_fight", {}).get("pending_opponent_action", ""))
    _check(locked_action == "guard", "v0.5 deterministic fixture did not lock guard")

    main_view._choose_fight_action("jab")

    var active: Dictionary = game_state.state.get("active_fight", {})
    var exchange: Dictionary = active.get("last_exchange", {})
    _check(not exchange.is_empty(), "v0.5 action did not persist exchange")
    _check(str(exchange.get("player_action", "")) == "jab", "v0.5 action persisted wrong player action")
    _check(str(exchange.get("opponent_action", "")) == locked_action, "v0.5 presentation changed locked opponent action")
    _check(not bool(exchange.get("finished", true)), "v0.5 deterministic presentation fixture unexpectedly finished the fight")

    # _clear_body() queue_frees the previous render, so the old idle FightStage
    # can coexist with the newly rendered stage until the frame ends. Select the
    # stage that actually consumed this exchange instead of the first node by name.
    var animated_stage: Node = _find_stage_with_event(main_view, 1)
    _check(is_instance_valid(animated_stage), "active fight stage did not register presentation event")
    if is_instance_valid(animated_stage):
        var expected_profile: String = Impact.profile(exchange)
        _check(str(animated_stage.get("last_animation_profile")) == expected_profile, "fight stage impact profile mismatch")
        _check(int(animated_stage.get("presentation_event_id")) == 1, "fight stage did not register presentation event")
        _check(not str(animated_stage.get("player_pose")).is_empty(), "player pose was not assigned")
        _check(not str(animated_stage.get("opponent_pose")).is_empty(), "opponent pose was not assigned")

    var feedback: Node = main_view.get_node_or_null("ImpactFeedback")
    _check(is_instance_valid(feedback), "impact feedback router was not created")
    if is_instance_valid(feedback):
        var expected: String = Impact.profile(exchange)
        _check(str(feedback.get("last_profile")) == expected, "impact feedback profile mismatch")
        _check(str(feedback.get("last_sfx_cue")) == Impact.sfx_cue(expected), "impact SFX cue mismatch")
        _check(int(feedback.get("last_haptic_ms")) == Impact.haptic_duration_ms(expected), "impact haptic duration mismatch")

    _finish()

func _test_impact_profiles() -> void:
    var counter_exchange := {
        "counter_success": true,
        "player_event": {"hit": true, "damage": 12.0, "knockout": false},
        "opponent_event": {}
    }
    _check(Impact.profile(counter_exchange) == "counter", "counter profile mapping failed")
    _check(Impact.sfx_cue("counter") == "counter_crack", "counter SFX cue mapping failed")
    _check(Impact.haptic_duration_ms("counter") > Impact.haptic_duration_ms("medium"), "counter haptic should exceed medium hit")

    var knockdown_exchange := {
        "counter_success": false,
        "player_event": {"hit": true, "damage": 20.0, "knockout": true},
        "opponent_event": {}
    }
    _check(Impact.profile(knockdown_exchange) == "knockdown", "knockdown profile mapping failed")
    _check(Impact.haptic_duration_ms("knockdown") >= 70, "knockdown haptic is too weak")

    var heavy_exchange := {
        "counter_success": false,
        "player_event": {"hit": true, "damage": 15.0, "knockout": false},
        "opponent_event": {}
    }
    _check(Impact.profile(heavy_exchange) == "heavy", "heavy hit profile mapping failed")

func _find_stage_with_event(root: Node, event_id: int) -> Node:
    if root is FightStage and int(root.get("presentation_event_id")) == event_id:
        return root
    for child in root.get_children():
        var found: Node = _find_stage_with_event(child, event_id)
        if is_instance_valid(found):
            return found
    return null

func _find_named(root: Node, target_name: String) -> Node:
    if str(root.name) == target_name:
        return root
    for child in root.get_children():
        var found: Node = _find_named(child, target_name)
        if is_instance_valid(found):
            return found
    return null

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("v05-fight-presentation-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

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
