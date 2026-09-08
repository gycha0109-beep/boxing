extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")
const CAPTURE_DIR := "res://visual-captures/v1.0-font"

var main_view: Control
var game_state: Node
var opponents: Array = []
var camps: Array = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
    _cleanup_save_files()
    await process_frame

    game_state = get_root().get_node_or_null("GameState")
    if game_state == null:
        _fail("GameState autoload unavailable")
        return

    opponents = _load_array("res://data/opponents.json")
    camps = _load_array("res://data/camp_actions.json")
    if opponents.is_empty() or camps.is_empty():
        _fail("capture fixtures are incomplete")
        return

    game_state.new_career("Release Boxer", "technician")
    game_state.state.erase("first_launch_acknowledged")
    game_state.state.erase("weigh_in_acknowledged")
    Save.save_game(game_state.state)

    var packed: PackedScene = load("res://scenes/Main.tscn")
    if packed == null:
        _fail("Main scene could not load")
        return

    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    if str(main_view.get_script().resource_path) != "res://scripts/main_v12.gd":
        _fail("capture is not using the v1.2 Legacy shell above the v1.0 release shell")
        return

    await _capture("01_title.png")

    main_view._start_new_career_from_title()
    await process_frame
    await _capture("02_camp.png")

    main_view._choose_camp_action(camps[0])
    await process_frame
    await _capture("03_fight_offer.png")

    var opponent: Dictionary = opponents[0]
    main_view._choose_opponent(opponent)
    await process_frame
    await _capture("04_scouting_game_plan.png")

    main_view._choose_game_plan("balanced")
    await process_frame
    await process_frame
    await _capture("05_weigh_in.png")

    main_view._acknowledge_weigh_in()
    await process_frame
    await process_frame
    await _capture("06_fight_opening.png")

    main_view._choose_fight_action("jab")
    await create_timer(0.18).timeout
    await _capture("07_fight_after_jab.png")
    await create_timer(0.40).timeout

    game_state.apply_fight_result("WIN_DEC", opponent, {"player_hp": 72.0, "opponent_hp": 44.0})
    main_view._render_phase()
    await process_frame
    await _capture("08_result.png")

    print("visual-capture-v10-font: PASS")
    _cleanup_save_files()
    quit(0)

func _capture(filename: String) -> void:
    await process_frame
    await process_frame
    var image := get_root().get_viewport().get_texture().get_image()
    if image.get_width() != 430 or image.get_height() != 932:
        _fail("unexpected viewport size %dx%d" % [image.get_width(), image.get_height()])
        return
    var path := "%s/%s" % [CAPTURE_DIR, filename]
    var err := image.save_png(ProjectSettings.globalize_path(path))
    if err != OK:
        _fail("failed to save %s" % path)
        return
    print("captured: %s" % path)

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
    push_error(message)
    _cleanup_save_files()
    quit(1)
