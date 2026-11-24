extends SceneTree

const SAVE := preload("res://scripts/core/save_service.gd")
func _init() -> void:
    call_deferred("_capture")
func _capture() -> void:
    var gs := root.get_node("GameState")
    gs.new_career("검증 복서", "balanced")
    gs.state["first_launch_acknowledged"] = true
    SAVE.save_game(gs.state)
    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    for n in range(6):
        await process_frame
    var title := ui.get_node_or_null("ReferenceTitle")
    if title == null:
        printerr("FAIL title not on root")
        quit(1)
        return
    var settings := title.find_child("TitleSettings", true, false) as Button
    var header := ui.find_child("V19TopBar", true, false)
    print("ROOT_TITLE:", title.size, " HUD_HIDDEN:", header != null and not header.visible, " SETTINGS:", settings != null)
    if header == null or header.visible or settings == null:
        quit(1)
        return
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    print("CAPTURE:", picture.save_png("res://docs/release/title-fullscreen-reference-430.png"), " SIZE:", picture.get_size())
    settings.pressed.emit()
    await process_frame
    await process_frame
    var settings_open := ui.find_child("DevFactoryResetButton", true, false) != null
    print("SETTINGS_OPEN:", settings_open, " TITLE_HIDDEN:", ui.get_node_or_null("ReferenceTitle") == null)
    if not settings_open:
        quit(1)
        return
    ui._v19_close_secondary()
    await process_frame
    await process_frame
    print("TITLE_RETURN:", ui.get_node_or_null("ReferenceTitle") != null)
    quit(0 if ui.get_node_or_null("ReferenceTitle") != null else 1)
