extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")
const CAPTURE_DIR := "res://visual-captures/v1.2-v18"

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
    if opponents.size() < 4 or camps.is_empty():
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

    if str(main_view.get_script().resource_path) != "res://scripts/main_v18_release.gd":
        _fail("capture is not using the active v18 release shell above the commercial photo/audio/economy/preparation/Legacy runtime")
        return

    await _capture("01_title.png")

    main_view._start_new_career_from_title()
    await process_frame
    main_view._choose_boxing_style("out_boxer")
    await process_frame
    main_view._confirm_talent()
    await process_frame
    await _capture("02_camp.png")

    main_view._open_equipment_shop()
    await process_frame
    var equipment_text := "\n".join(_collect_text(main_view))
    if not equipment_text.contains("번 돈을 복서에게 다시 투자") or not equipment_text.contains("개인 장비") or not equipment_text.contains("체육관 장비"):
        _fail("equipment investment screen did not render its required player-facing sections")
        return
    await _capture("03_equipment_shop.png")
    main_view._return_from_equipment_shop()
    await process_frame

    main_view._choose_camp_action(camps[0])
    await process_frame
    await _capture("04_fight_offer.png")

    # park_tae-ho is the v18 US/black-photo fixture. Use it deliberately so
    # the approved mockup's photo-ring path is exercised rather than only the
    # dynamic FightStage fallback.
    var opponent: Dictionary = opponents[3]
    if str(opponent.get("id", "")) != "park_tae-ho":
        _fail("v18 photo-ring fixture changed unexpectedly")
        return
    main_view._choose_opponent(opponent)
    await process_frame
    main_view._choose_tactical_preparation("distance_drill")
    await process_frame
    main_view._choose_condition_preparation("sharpness")
    await process_frame
    await _capture("05_scouting_game_plan.png")

    main_view._choose_game_plan("balanced")
    await process_frame
    await process_frame
    await _capture("06_weigh_in.png")

    main_view._acknowledge_weigh_in()
    await process_frame
    await process_frame
    var fight_text := "\n".join(_collect_text(main_view))
    for marker in ["RING", "Marcus Bell", "2:48", "OPPONENT READ", "다음 행동"]:
        if not fight_text.contains(marker):
            _fail("v18 fight opening missing marker: %s" % marker)
            return
    await _capture("07_fight_opening.png")

    main_view._choose_fight_action("jab")
    await create_timer(0.18).timeout
    await _capture("08_fight_after_jab.png")
    await create_timer(0.40).timeout

    game_state.apply_fight_result("WIN_DEC", opponent, {"player_hp": 72.0, "opponent_hp": 44.0})
    main_view._render_phase()
    await process_frame
    await _capture("09_result.png")

    print("visual-capture-v18-commercial: PASS")
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

func _collect_text(root: Node) -> Array[String]:
    var values: Array[String] = []
    if root is Label:
        values.append(str((root as Label).text))
    elif root is Button:
        values.append(str((root as Button).text))
    for child in root.get_children():
        values.append_array(_collect_text(child))
    return values

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
    push_error(message)
    _cleanup_save_files()
    quit(1)