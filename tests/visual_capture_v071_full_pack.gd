extends SceneTree

const CAPTURE_DIR := "res://visual-captures"
const STYLE_INDEX := {
    "swarmer": 0,
    "outboxer": 1,
    "slugger": 2,
    "counter": 3,
}
const POSES := ["idle", "jab", "power", "body", "guard", "counter", "hurt", "down"]

var game_state: Node
var opponents: Array = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
    game_state = get_root().get_node_or_null("GameState")
    if game_state == null:
        push_error("GameState autoload unavailable")
        quit(1)
        return
    opponents = _load_array("res://data/opponents.json")
    if opponents.size() < 4:
        push_error("representative opponents unavailable")
        quit(1)
        return
    for style in STYLE_INDEX.keys():
        var ok := await _capture_style(style, int(STYLE_INDEX[style]))
        if not ok:
            quit(1)
            return
    print("visual-capture-v071-full-pack: PASS")
    quit(0)

func _capture_style(style: String, opponent_index: int) -> bool:
    game_state.new_career("Visual Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    var packed: PackedScene = load("res://scenes/Main.tscn")
    var main_view: Control = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame
    var opponent: Dictionary = opponents[opponent_index]
    main_view.current_opponent = opponent
    game_state.state.phase = "fight_offer"
    game_state.select_opponent(opponent)
    main_view._render_phase()
    var selected: Dictionary = game_state.select_game_plan("counter_trap")
    if not bool(selected.get("ok", false)):
        push_error("could not select counter_trap for %s" % style)
        main_view.queue_free()
        return false
    main_view._render_phase()
    await process_frame
    await process_frame
    var stage := main_view.find_child("FightStage", true, false) as FightStage
    if stage == null:
        push_error("FightStage unavailable for %s" % style)
        main_view.queue_free()
        return false
    stage.telegraph_action = ""
    stage.last_exchange = {}
    stage.animation_progress = 0.0
    stage.impact_flash = 0.0
    for pose in POSES:
        stage.player_pose = "guard"
        stage.opponent_pose = pose
        stage.queue_redraw()
        await _capture("%s_%s.png" % [style, pose])
    main_view.queue_free()
    await process_frame
    return true

func _capture(filename: String) -> void:
    await process_frame
    await process_frame
    var image := get_root().get_viewport().get_texture().get_image()
    var path := "%s/%s" % [CAPTURE_DIR, filename]
    var err := image.save_png(ProjectSettings.globalize_path(path))
    if err != OK:
        push_error("failed to save %s" % path)
        quit(1)
    print("captured: %s" % path)

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []
