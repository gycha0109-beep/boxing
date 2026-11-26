extends SceneTree

const TITLE := preload("res://scripts/ui/reference_title_view.gd")
const UI := preload("res://scripts/ui/reference_ui.gd")

func _init() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var view := TITLE.new()
    var font := FontVariation.new()
    font.base_font = load("res://assets/fonts/NotoSansKR-VF.ttf")
    view.heading_font = UI.heading_font(font)
    view.bold_font = load("res://assets/fonts/NotoSansKR-VF.ttf")
    view.can_continue = true
    view.save_caption = "레이어 검증 · 2세대"
    root.add_child(view)
    view.position = Vector2(12, 12)
    view.size = Vector2(406, 900)
    await process_frame
    await process_frame
    var scene := view.find_child("TitleCoverLayers", true, false) as Control
    var background := view.find_child("TitleArenaBackground", true, false) as TextureRect
    var foreground := view.find_child("TitleBoxerForeground", true, false) as TextureRect
    var start := view.find_child("TitleNewCareer", true, false) as Button
    var resume := view.find_child("TitleContinue", true, false) as Button
    var belt := view.find_child("TitleLegacyBelt", true, false) as TextureRect
    var dust := view.find_child("TitleArenaDust", true, false) as CPUParticles2D
    var names: Array[String] = []
    for node in view.find_children("*", "Label", true, false):
        names.append((node as Label).text)
    var good := scene != null and background != null and foreground != null and start != null and resume != null and belt != null and dust != null
    if good:
        good = background.texture != null and foreground.texture != null and background.texture != foreground.texture
        good = scene.get_child_count() >= 4 and start.text == "새 커리어 시작" and resume.text == "이어하기"
        good = good and names.has("TWELVE COUNT") and names.has("데뷔전부터 세계 타이틀전까지")
        good = good and names.has("복서를 만들고 커리어를 이어가라")
        good = good and background.material is ShaderMaterial
        good = good and foreground.material is ShaderMaterial
        good = good and belt.material is ShaderMaterial
        good = good and dust.amount >= 20 and dust.emitting
        good = good and (view.find_child("TitleLiveLogo", true, false) as Label).material is ShaderMaterial
    if not good:
        printerr("FAIL: title background, boxer, live text or buttons aren't independently instantiated.")
        quit(1)
        return
    print("PASS: independent title layers, arena lighting shader, boxer rim shader, belt metal shader and dust particles")
    quit(0)
