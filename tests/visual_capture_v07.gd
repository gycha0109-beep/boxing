extends SceneTree

const CAPTURE_DIR := "res://visual-captures"
var main_view: Control
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
    if opponents.is_empty():
        push_error("no opponents")
        quit(1)
        return

    game_state.new_career("Visual Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    var packed: PackedScene = load("res://scenes/Main.tscn")
    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    game_state.state.phase = "camp"
    main_view._render_phase()
    await _capture("01_camp.png")

    game_state.state.phase = "fight_offer"
    main_view._render_phase()
    await _capture("02_fight_offers.png")

    var opponent: Dictionary = opponents[0]
    main_view.current_opponent = opponent
    game_state.select_opponent(opponent)
    main_view._render_phase()
    await _capture("03_game_plan.png")

    var selected: Dictionary = game_state.select_game_plan("counter_trap")
    if not bool(selected.get("ok", false)):
        push_error("could not select counter_trap")
        quit(1)
        return
    main_view._render_phase()
    await _capture("04_fight_opening.png")

    main_view._choose_fight_action("jab")
    await create_timer(0.18).timeout
    await _capture("05_fight_after_jab.png")

    print("visual-capture-v07: PASS")
    quit(0)

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
