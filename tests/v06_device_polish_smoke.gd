extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")
const SafeArea = preload("res://scripts/ui/safe_area_layout.gd")
const Impact = preload("res://scripts/ui/impact_feedback.gd")
const Fx = preload("res://scripts/ui/fight_fx_director.gd")
const Arena = preload("res://scripts/ui/arena_audio.gd")
const Stage = preload("res://scripts/ui/fight_stage.gd")

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_safe_area_math()
    _test_impact_targeting_and_haptics()
    await _test_fx_and_arena_runtime()
    _cleanup_save_files()
    await process_frame

    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState autoload was not available")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "v0.6 fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

    game_state.new_career("Device Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    game_state.state.phase = "fight_offer"
    game_state.select_opponent(opponents[0])
    var selected: Dictionary = game_state.select_game_plan("counter_trap")
    _check(bool(selected.get("ok", false)), "v0.6 fixture could not select game plan")

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load for v0.6")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _check(str(main_view.get_script().resource_path) == "res://scripts/main_v07.gd", "Main scene is not using the v0.7 shell that inherits v0.6 device runtime")
    var buttons: Array[Button] = _buttons_under(main_view)
    _check(not buttons.is_empty(), "v0.6 fight screen rendered no buttons")
    for button in buttons:
        _check(button.custom_minimum_size.y >= 56.0, "touch target below 56 logical pixels")

    var arena_node: Node = main_view.get_node_or_null("ArenaAudio")
    _check(is_instance_valid(arena_node), "arena audio router was not created on fight start")
    if is_instance_valid(arena_node):
        _check(bool(arena_node.get("crowd_active")), "crowd ambience was not activated")
        _check(int(arena_node.get("cue_count")) >= 1, "opening bell was not routed")

    var pause_before: int = int(main_view.get("lifecycle_pause_saves"))
    main_view._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
    _check(int(main_view.get("lifecycle_pause_saves")) == pause_before + 1, "pause notification did not persist runtime state")
    main_view._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
    _check(int(main_view.get("lifecycle_resumes")) >= 1, "resume notification was not handled")

    main_view._choose_fight_action("jab")
    await process_frame
    var fx_node: Node = main_view.get_node_or_null("FightFxDirector")
    _check(is_instance_valid(fx_node), "fight FX director was not wired into actual Main fight action")
    if is_instance_valid(fx_node):
        _check(int(fx_node.get("presentation_event_id")) == 1, "actual fight action did not register FX event")
    _check(bool(main_view.get("fight_input_locked")), "fight input was not locked during presentation window")
    await create_timer(0.50).timeout
    _check(not bool(main_view.get("fight_input_locked")), "fight input did not unlock after time-based presentation window")

    _finish()

func _test_safe_area_math() -> void:
    var insets: Dictionary = SafeArea.compute_insets(
        Vector2(430.0, 932.0),
        Vector2(1290.0, 2796.0),
        Rect2i(0, 132, 1290, 2532)
    )
    _check(is_equal_approx(float(insets.top), 44.0), "safe-area top inset scaling failed")
    _check(is_equal_approx(float(insets.bottom), 44.0), "safe-area bottom inset scaling failed")
    _check(is_equal_approx(float(insets.left), 0.0), "safe-area left inset scaling failed")

func _test_impact_targeting_and_haptics() -> void:
    var body_exchange := {
        "player_action": "body",
        "opponent_action": "guard",
        "counter_success": false,
        "player_event": {"hit": true, "damage": 10.0, "knockout": false},
        "opponent_event": {}
    }
    _check(Impact.profile(body_exchange) == "medium", "body fixture should map to medium profile")
    _check(Impact.sfx_cue_for_exchange(body_exchange) == "body_hit", "body hit did not route to body-specific cue")
    _check(Impact.haptic_amplitude("heavy") > Impact.haptic_amplitude("medium"), "heavy haptic amplitude should exceed medium")
    _check(Impact.hit_stop_seconds("counter") > Impact.hit_stop_seconds("medium"), "counter hit-stop should exceed medium")
    _check(Impact.shake_strength("knockdown") > Impact.shake_strength("heavy"), "knockdown shake should exceed heavy")

    var counter_exchange := {
        "player_action": "counter",
        "opponent_action": "power",
        "counter_success": true,
        "player_event": {"hit": true, "damage": 12.0, "knockout": false},
        "opponent_event": {}
    }
    _check(Impact.sfx_cue_for_exchange(counter_exchange) == "head_crack", "counter did not route to head-crack cue")

func _test_fx_and_arena_runtime() -> void:
    var stage := Stage.new()
    get_root().add_child(stage)
    await process_frame
    var director := Fx.new()
    get_root().add_child(director)
    await process_frame
    var heavy_exchange := {
        "player_action": "power",
        "opponent_action": "guard",
        "counter_success": false,
        "player_event": {"hit": true, "damage": 15.0, "knockout": false},
        "opponent_event": {}
    }
    director.trigger(stage, heavy_exchange)
    _check(director.last_profile == "heavy", "FX director profile mismatch")
    _check(director.last_hit_stop_seconds > 0.0, "heavy hit-stop was not scheduled")
    _check(director.last_shake_strength > 0.0, "heavy screen shake was not scheduled")
    _check(stage.process_mode == Node.PROCESS_MODE_DISABLED, "stage was not locally frozen for hit-stop")
    await create_timer(0.07).timeout
    _check(stage.process_mode != Node.PROCESS_MODE_DISABLED, "stage did not resume after hit-stop")
    stage.queue_free()
    director.queue_free()

    var arena := Arena.new()
    get_root().add_child(arena)
    await process_frame
    arena.start_fight()
    _check(arena.crowd_active, "arena crowd did not start")
    _check(arena.last_cue == "round_bell", "opening bell cue mismatch")
    _check(float(Arena.cue_profile("round_bell").duration) >= 0.15, "round bell cue is too short")
    arena.set_suspended(true)
    _check(arena.suspended, "arena audio did not suspend")
    arena.set_suspended(false)
    _check(not arena.suspended, "arena audio did not resume")
    arena.queue_free()
    await process_frame

func _buttons_under(node: Node) -> Array[Button]:
    var result: Array[Button] = []
    for child in node.get_children():
        if child is Button:
            result.append(child as Button)
        result.append_array(_buttons_under(child))
    return result

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("v06-device-polish-smoke: PASS")
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
