extends SceneTree

const CAPTURE_DIR := "res://visual-captures"
var main_view: Control
var game_state: Node
var opponents: Array = []
var camps: Array = []

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
    camps = _load_array("res://data/camp_actions.json")
    if opponents.is_empty() or camps.is_empty():
        push_error("capture fixtures unavailable")
        quit(1)
        return

    game_state.new_career("비주얼 복서", "technician")
    game_state.state.erase("first_launch_acknowledged")
    game_state.state.erase("weigh_in_acknowledged")
    SaveService.save_game(game_state.state)

    var packed: PackedScene = load("res://scenes/Main.tscn")
    if packed == null:
        push_error("Main scene unavailable")
        quit(1)
        return
    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    await _capture("v08_01_title.png")
    main_view._start_new_career_from_title()
    await _capture("v08_02_camp.png")
    main_view._choose_camp_action(camps[0])
    await _capture("v08_03_fight_offers.png")

    var opponent: Dictionary = opponents[0]
    main_view._choose_opponent(opponent)
    await _capture("v08_04_game_plan.png")
    main_view._choose_game_plan("counter_trap")
    await _capture("v08_05_weigh_in.png")
    main_view._acknowledge_weigh_in()
    await _capture("v08_06_fight_opening.png")

    main_view._choose_fight_action("jab")
    await create_timer(0.08).timeout
    await _capture("v08_07_jab_contact.png")
    await create_timer(0.14).timeout
    await _capture("v08_08_jab_recovery.png")

    game_state.apply_fight_result("WIN_DEC", opponent, {"player_hp":72.0, "opponent_hp":44.0})
    main_view._render_phase()
    await _capture("v08_09_result.png")

    print("visual-capture-v08-first-five-r3: PASS")
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