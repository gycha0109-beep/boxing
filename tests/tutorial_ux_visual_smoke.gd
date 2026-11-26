extends SceneTree

const Save := preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var game: Node
var ui: Control


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: isolated user-data directory required")
        quit(2)
        return

    game = root.get_node("GameState")
    game.new_career("Tutorial Entry QA", "technician")
    game.state.erase("first_launch_acknowledged")
    Save.save_game(game.state)

    ui = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await _settle()
    ui._onboarding_install.set_value("install", "tutorial_started", true)
    ui._onboarding_install.save("user://onboarding_install.cfg")
    ui._guide_settings.set_value("tutorial", "enabled", false)
    ui._guide_settings.save("user://first_bout_guide.cfg")
    ui._return_to_reference_title()

    var start := ui.find_child("TitleNewCareer", true, false) as Button
    _check(start != null, "new career button missing")
    if start != null:
        start.pressed.emit()
    await _settle()

    var consent := ui.find_child("TutorialConsentDialog", true, false) as ConfirmationDialog
    _check(consent != null and consent.visible, "tutorial consent popup missing")
    _check(str(game.state.get("phase", "")) != "home", "home appeared before boxer creation")
    _check(ui.body.get_node_or_null("ReferenceBoxerCreation") == null, "boxer creation appeared before consent")

    # Closing with the window X must not consume the title button's one-shot guard.
    if consent != null:
        consent.close_requested.emit()
    await _settle()
    _check(ui._tutorial_consent_dialog == null, "closing with X did not release the dialog reference")
    var title_view := ui.get_node_or_null("ReferenceTitle")
    _check(title_view != null and not bool(title_view.get("_leaving")), "closing with X left the title button locked")
    start = ui.find_child("TitleNewCareer", true, false) as Button
    if start != null:
        start.pressed.emit()
    await _settle()
    consent = ui.find_child("TutorialConsentDialog", true, false) as ConfirmationDialog
    _check(consent != null and consent.visible, "new career button did not reopen tutorial choice after X")

    if consent != null:
        consent.get_ok_button().pressed.emit()
    await _settle()

    _check(str(game.state.get("phase", "")) == "style_select", "accepting tutorial must enter boxer creation")
    _check(bool(game.state.get("first_cycle_tutorial", {}).get("active", false)), "tutorial was not enabled")
    _check(ui.body.get_node_or_null("ReferenceBoxerCreation") != null, "boxer creation screen missing after consent")
    _check(ui.get_node_or_null("FirstCycleSpotlight") != null, "coach spotlight missing after consent")
    _check(ui.body.get_node_or_null("ReferenceHome") == null, "home screen replaced boxer creation")
    _check(not ui.v19_bottom_nav.visible, "career navigation appeared before boxer creation")

    ui._return_to_reference_title()
    ui._request_tutorial_consent()
    await _settle()
    consent = ui.find_child("TutorialConsentDialog", true, false) as ConfirmationDialog
    _check(consent != null and consent.visible, "second tutorial choice did not open")
    if consent != null:
        consent.get_cancel_button().pressed.emit()
    await _settle()

    _check(str(game.state.get("phase", "")) == "style_select", "declining tutorial must still enter boxer creation")
    _check(not bool(game.state.get("first_cycle_tutorial", {}).get("active", true)), "declining tutorial left guidance active")
    _check(ui.body.get_node_or_null("ReferenceBoxerCreation") != null, "declining tutorial skipped boxer creation")
    _check(ui.body.get_node_or_null("ReferenceHome") == null, "declining tutorial opened home before boxer creation")

    ui.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: consent popup -> boxer creation for both tutorial choices; home never appears before creation")
        quit(0)
    else:
        printerr("FAIL: tutorial entry flow: ", failures)
        quit(1)


func _settle() -> void:
    for _i in range(4):
        await process_frame


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)
