extends SceneTree

const Save := preload("res://scripts/core/save_service.gd")

var game: Node
var ui: Control
var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("Use an isolated _sandbox_user_data directory for the title test.")
        quit(2)
        return
    game = root.get_node("GameState")
    game.new_career("무명 복서", "technician")
    game.state.erase("first_launch_acknowledged")
    Save.save_game(game.state)
    await _open()
    var resume := _button("TitleContinue")
    _check(resume != null and resume.disabled, "fresh title must not continue the bootstrap boxer")
    _check(not ui.v19_bottom_nav.visible and ui.v19_settings_button.visible, "title must keep settings without career navigation")
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    var before_consent: Dictionary = Save.load_game().duplicate(true)
    _check(_press("TitleNewCareer"), "fresh title must expose its start button")
    await _settle()
    var consent := ui.find_child("TutorialConsentDialog", true, false) as ConfirmationDialog
    _check(consent != null and consent.visible, "new career must ask whether to start the tutorial")
    _check(Save.load_game() == before_consent, "opening tutorial consent must not create or replace a boxer")
    if consent != null:
        consent.get_ok_button().pressed.emit()
    await _settle()
    _check(Save.load_game().get("phase") == "style_select", "accepting tutorial must enter boxer creation")
    _check(bool(Save.load_game().get("first_cycle_tutorial", {}).get("active", false)), "accepted tutorial must remain active")
    ui._return_to_reference_title()
    await create_timer(4.0).timeout
    _check(_press("TitleContinue"), "unfinished boxer creation must be resumable from the title")
    await _settle()
    _check(Save.load_game().get("phase") == "style_select", "continue must resume boxer creation instead of home")
    _check(ui.body.get_node_or_null("ReferenceBoxerCreation") != null, "continue sent an unfinished boxer to the home screen")
    _check(ui.get_node_or_null("FirstCycleSpotlight") != null, "continue did not restore the active coach guidance")
    ui._skip_first_bout_guide()
    await _settle()

    var creation := Save.load_game()
    await _open_title_from_menu()
    _check(_press("TitleContinue"), "creation can be resumed from the title")
    await _settle()
    _check(Save.load_game() == creation, "continuing creation must leave the save intact")
    _check(bool(game.select_boxing_style("balanced").get("ok", false)), "fixture must choose a boxing style")
    _check(bool(game.confirm_talent().get("ok", false)), "fixture must enter camp")
    game.state.boxer.name = "저장 검증"
    game.state.career.money = 175000
    game.state.meta_state.generation = 3
    game.state.meta_state.legacy_slots = [{"definition_id": "recovery_routine", "source_generation": 2}]
    _check(bool(game.apply_camp_action(ui.camp_actions[0]).get("ok", false)), "fixture must reach fight offers")
    var saved := Save.load_game()
    await _close()
    game.state = Save.load_game()
    await _open()
    _check(ui.find_child("ReferenceTitle", true, false) != null, "relaunch must open the title even with an existing saved career")
    _check(_button("TitleContinue") != null and not _button("TitleContinue").disabled, "saved career must be available through Continue")

    _check(_press("TitleNewCareer"), "new game button on a save must open a confirmation")
    await _settle()
    var warning := ui.find_child("TitleConfirmOverwrite", true, false) as ConfirmationDialog
    _check(warning != null and warning.visible and Save.load_game() == saved, "opening confirmation must not replace the save")
    if warning != null:
        warning.get_cancel_button().pressed.emit()
        await _settle()
        _check(not warning.visible and Save.load_game() == saved, "cancel must keep the career and legacy")
    _check(_press("TitleContinue"), "saved game must have an enabled continue button")
    await _settle()
    _check(game.state.get("phase") == "fight_offer" and Save.load_game() == saved, "continue must restore the same phase, money, boxer and legacy")

    await _open_title_from_menu()
    _check(_press("TitleNewCareer"), "confirmed restart must start from the same confirmation")
    await _settle()
    warning = ui.find_child("TitleConfirmOverwrite", true, false) as ConfirmationDialog
    if warning != null:
        warning.get_ok_button().pressed.emit()
    await _settle()
    var consent_after_restart := ui.find_child("TutorialConsentDialog", true, false) as ConfirmationDialog
    _check(consent_after_restart != null and consent_after_restart.visible, "confirmed restart must ask for tutorial choice")
    if consent_after_restart != null:
        consent_after_restart.get_cancel_button().pressed.emit()
    await _settle()
    var fresh := Save.load_game()
    _check(fresh.phase == "style_select" and int(fresh.meta_state.generation) == 1 and fresh.meta_state.legacy_slots.is_empty(), "restart must enter boxer creation after consent")
    _check(not bool(fresh.get("first_cycle_tutorial", {}).get("active", true)), "declining tutorial must still create a boxer without guidance")

    await _close()
    await create_timer(0.30).timeout
    if failures.is_empty():
        print("PASS: title start, automatic resume, manual continue, cancel and confirmed replacement")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)

func _open() -> void:
    ui = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await _settle()
    await create_timer(4.0).timeout

func _close() -> void:
    ui.queue_free()
    await _settle()

func _open_title_from_menu() -> void:
    _check(_press("V19MenuButton"), "career must expose the menu")
    await _settle()
    for button in ui.body.find_children("*", "Button", true, false):
        if button.text == "타이틀 화면":
            button.pressed.emit()
            break
    await _settle()
    await create_timer(0.6).timeout
    _check(ui.find_child("ReferenceTitle", true, false) != null, "menu must open the reference title")

func _press(node_name: String) -> bool:
    var button := _button(node_name)
    if button == null or button.disabled:
        return false
    button.pressed.emit()
    return true

func _button(node_name: String) -> Button:
    return ui.find_child(node_name, true, false) as Button

func _settle() -> void:
    await process_frame
    await process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
