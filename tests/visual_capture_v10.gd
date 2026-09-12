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
    get_root().gui_embed_subwindows = true
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
        _fail("capture is not using the active release shell")
        return

    await _capture("01_title.png")

    main_view._start_new_career_from_title()
    await process_frame
    main_view._choose_boxing_style("out_boxer")
    await process_frame
    main_view._confirm_talent()
    await process_frame
    await _capture("02_camp.png")
    main_view._v17_open_overlay("profile")
    await _capture("10_profile.png")
    for stat_id in ["power", "speed", "technique", "defense", "conditioning"]:
        var help := main_view.find_child("StatHelp_" + stat_id, true, false) as Button
        if help == null:
            _fail("stat help button missing: " + stat_id)
            return
        help.pressed.emit()
        await process_frame
        if not main_view.stat_help_dialog.visible:
            _fail("stat help popup did not open: " + stat_id)
            return
        if stat_id == "speed":
            await _capture("16_stat_help.png")
        main_view.stat_help_dialog.hide()
    main_view._v17_open_match()
    await process_frame

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

    # Use the real US opponent, never a renamed Korean fixture.
    var opponent: Dictionary = opponents[13]
    main_view._choose_opponent(opponent)
    await process_frame
    var tactical_text := "\n".join(_collect_text(main_view))
    for marker in ["전술 준비", "다음 상대", str(opponent.name), "매치업 플랜", "01", "04"]:
        if not tactical_text.contains(marker):
            _fail("redesigned tactical preparation missing marker: %s" % marker)
            return
    await _capture("11_tactical_preparation.png")
    main_view._choose_tactical_preparation("distance_drill")
    await process_frame
    await _capture("12_condition_preparation.png")
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
    for marker in [str(opponent.name), "2:48", "상대 읽기", "코너 조언", "다음 행동"]:
        if not fight_text.contains(marker):
            _fail("redesigned fight opening missing marker: %s" % marker)
            return
    if fight_text.contains("OPPONENT READ") or fight_text.contains("★ PLAN"):
        _fail("legacy fight dashboard copy survived the v19 redesign")
        return
    var bottom_nav := main_view.find_child("V19BottomNav", true, false) as Control
    if not is_instance_valid(bottom_nav) or bottom_nav.visible:
        _fail("bottom app navigation must be hidden during combat")
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

    for fixture in [
        {"index": 0, "file": "13_fight_korean.png"},
        {"index": 12, "file": "14_fight_latino.png"},
        {"index": 15, "file": "15_fight_european.png"},
        {"index": 10, "file": "19_fight_yoon.png"},
        {"index": 11, "file": "20_fight_nakamura.png"},
        {"index": 12, "file": "21_fight_miguel.png"},
        {"index": 13, "file": "22_fight_evan.png"},
        {"index": 14, "file": "23_fight_mateo.png"},
        {"index": 15, "file": "24_fight_viktor.png"},
        {"index": 16, "file": "25_fight_diego.png"}
    ]:
        game_state.new_career("무명 복서", "technician")
        game_state.state["first_launch_acknowledged"] = true
        game_state.state["weigh_in_acknowledged"] = true
        game_state.state.phase = "fight_offer"
        var rival: Dictionary = opponents[fixture.index]
        game_state.select_opponent(rival)
        game_state.select_tactical_preparation("distance_drill")
        game_state.select_condition_preparation("sharpness")
        game_state.select_game_plan("balanced")
        main_view.current_opponent = rival
        main_view.combat = null
        main_view._render_phase()
        await _capture(fixture.file)

    var stages := main_view.find_children("*", "FightStage", true, false)
    if stages.size() != 1:
        _fail("expected exactly one FightStage for hurt/knockdown capture")
        return
    var stage := stages[0] as FightStage
    stage.telegraph_action = ""
    stage.player_pose = "hurt"
    stage.opponent_pose = "hurt"
    stage.animation_progress = 1.0
    await _capture("17_fight_hurt.png")
    stage.player_pose = "idle"
    stage.opponent_pose = "down"
    stage.animation_progress = 0.0
    await _capture("18_fight_knockdown.png")

    print("visual-capture-v19-redesign: PASS")
    _cleanup_save_files()
    quit(0)

func _capture(filename: String) -> void:
    await process_frame
    var fight_capture := "fight_" in filename and filename != "04_fight_offer.png"
    if fight_capture:
        var settled: bool = await _wait_for_fixed_fight_layout()
        if not settled:
            var failed_scroll := main_view.find_child("V17ContentScroll", true, false) as ScrollContainer
            var failed_content := main_view.body as Control
            _fail("fixed fight HUD did not settle in %s (content_end=%.2f viewport_end=%.2f)" % [filename, failed_content.get_global_rect().end.y, failed_scroll.get_global_rect().end.y])
            return
    var scroll := main_view.find_child("V17ContentScroll", true, false) as ScrollContainer
    var content := main_view.body as Control
    if content.get_global_rect().end.x > 431:
        _fail("horizontal content overflow in " + filename)
        return
    if filename == "02_camp.png":
        for card in main_view.find_children("CampCard_*", "VBoxContainer", true, false):
            if card.get_global_rect().end.y > scroll.get_global_rect().end.y + 1:
                _fail("four primary camp CTAs do not fit the first screen: " + str(card.name))
                return
    if filename == "04_fight_offer.png":
        for card in main_view.find_children("OpponentCard_*", "VBoxContainer", true, false):
            if card.get_global_rect().end.y > scroll.get_global_rect().end.y + 1:
                _fail("opponent CTA is outside the first viewport: " + str(card.name))
                return
    if fight_capture and not _fixed_fight_layout_ready(scroll, content):
        _fail("fixed fight HUD overflows in " + filename)
        return
    await process_frame
    _redraw_tree(main_view)
    await RenderingServer.frame_post_draw
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

func _wait_for_fixed_fight_layout(max_frames: int = 24, required_stable_frames: int = 2) -> bool:
    var stable_frames := 0
    for _frame in range(max_frames):
        await process_frame
        var scroll := main_view.find_child("V17ContentScroll", true, false) as ScrollContainer
        var content := main_view.body as Control
        if _fixed_fight_layout_ready(scroll, content):
            stable_frames += 1
            if stable_frames >= required_stable_frames:
                return true
        else:
            stable_frames = 0
    return false

func _fixed_fight_layout_ready(scroll: ScrollContainer, content: Control) -> bool:
    if not is_instance_valid(scroll) or not is_instance_valid(content):
        return false
    if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        return false
    if content.get_global_rect().end.y > scroll.get_global_rect().end.y + 1:
        return false
    if main_view.find_children("*", "FightStage", true, false).size() != 1:
        return false
    var bottom_nav := main_view.find_child("V19BottomNav", true, false) as Control
    if not is_instance_valid(bottom_nav) or bottom_nav.visible:
        return false
    for button in main_view._buttons_under(content):
        if not scroll.get_global_rect().encloses(button.get_global_rect()):
            return false
    return true

func _redraw_tree(node: Node) -> void:
    if node is CanvasItem: node.queue_redraw()
    for child in node.get_children():
        _redraw_tree(child)

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
