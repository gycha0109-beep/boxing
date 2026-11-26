extends SceneTree

const TITLE := preload("res://scripts/ui/reference_title_view.gd")
const UI := preload("res://scripts/ui/reference_ui.gd")

func _init() -> void:
    call_deferred("_verify_skip")

func _verify_skip() -> void:
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR-VF.ttf")
    var view := TITLE.new()
    view.heading_font = UI.heading_font(font)
    view.bold_font = font
    view.can_continue = true
    root.add_child(view)
    view.position = Vector2.ZERO
    view.size = Vector2(430, 932)
    await process_frame
    await process_frame
    var skip := view.find_child("TitleIntroSkip", true, false) as Button
    if skip == null:
        printerr("FAIL: intro skip control missing.")
        quit(1)
        return
    skip.pressed.emit()
    await process_frame
    var passed := not bool(view.get("_intro_running"))
    passed = passed and view.find_child("TitleIntroBlackOverlay", true, false) == null
    passed = passed and not (view.find_child("TitleNewCareer", true, false) as Button).disabled
    passed = passed and (view.get("_arena_light_material") as ShaderMaterial).get_shader_parameter("light_intensity") > 0.9
    passed = passed and (view.get("_boxer_rim_material") as ShaderMaterial).get_shader_parameter("rim_strength") > 0.8
    passed = passed and (view.get("_belt_metal_material") as ShaderMaterial).get_shader_parameter("shine_intensity") > 0.8
    if passed:
        print("PASS: intro skip immediately reveals title and enables actions.")
        quit(0)
    else:
        printerr("FAIL: intro skip did not complete the title reveal.")
        quit(1)
