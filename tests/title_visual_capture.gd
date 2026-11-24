extends SceneTree

const TITLE := preload("res://scripts/ui/reference_title_view.gd")
const UI := preload("res://scripts/ui/reference_ui.gd")

func _init() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var heading := FontVariation.new()
    heading.base_font = load("res://assets/fonts/NotoSansKR-VF.ttf")
    heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 780.0}
    var bold := FontVariation.new()
    bold.base_font = heading.base_font
    bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 580.0}
    var view := TITLE.new()
    view.heading_font = UI.heading_font(heading)
    view.bold_font = bold
    view.can_continue = true
    view.save_caption = "김도현 · 2세대 · 4전"
    var target_width := int(OS.get_environment("TITLE_CAPTURE_WIDTH"))
    var target_height := int(OS.get_environment("TITLE_CAPTURE_HEIGHT"))
    if target_width <= 0:
        target_width = 430
    if target_height <= 0:
        target_height = 932
    root.size = Vector2i(target_width, target_height)
    root.add_child(view)
    view.position = Vector2(8, 8)
    await process_frame
    # The display server can clamp requested window sizes; use its actual texture.
    var actual_width := root.get_texture().get_width()
    view.size = Vector2(actual_width - 16, 900)
    await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    if img == null:
        printerr("CAPTURE FAIL: no renderer output")
        quit(1)
        return
    var result := img.save_png("res://docs/release/title-v2-layered-%d.png" % target_width)
    print("TITLE_CAPTURE: ", result, " ", img.get_width(), "x", img.get_height())
    quit(0)
