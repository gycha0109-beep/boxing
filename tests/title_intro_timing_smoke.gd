extends SceneTree

const TITLE := preload("res://scripts/ui/reference_title_view.gd")
const UI := preload("res://scripts/ui/reference_ui.gd")

func _init() -> void:
    call_deferred("_verify_intro")

func _verify_intro() -> void:
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR-VF.ttf")
    var view := TITLE.new()
    view.heading_font = UI.heading_font(font)
    view.bold_font = font
    view.can_continue = true
    view.save_caption = "인트로 테스트"
    root.add_child(view)
    view.position = Vector2.ZERO
    view.size = Vector2(430, 932)
    await create_timer(4.2).timeout

    var checks := {
        "intro_completed": not bool(view.get("_intro_running")),
        "black_overlay_removed": view.find_child("TitleIntroBlackOverlay", true, false) == null,
        "boxer_visible": (view.get("_title_boxer") as Control).modulate.a > 0.99,
        "belt_visible": (view.get("_title_belt") as Control).modulate.a > 0.99,
        "start_button_visible": (view.get("_title_start_button") as Control).modulate.a > 0.99,
        "continue_enabled": not (view.get("_title_resume_button") as Button).disabled,
        "arena_lighting_enabled": (view.get("_arena_light_material") as ShaderMaterial).get_shader_parameter("light_intensity") > 0.9,
        "boxer_rim_enabled": (view.get("_boxer_rim_material") as ShaderMaterial).get_shader_parameter("rim_strength") > 0.8,
        "belt_metal_enabled": (view.get("_belt_metal_material") as ShaderMaterial).get_shader_parameter("shine_intensity") > 0.8
    }
    var failed: Array[String] = []
    for key in checks:
        if not checks[key]:
            failed.append(key)
    if failed.is_empty():
        print("PASS: title intro completed; arena, boxer, belt and buttons are revealed.")
        quit(0)
    else:
        printerr("FAIL: title intro checks: ", failed)
        quit(1)
