extends Control

signal skipped()

const COACH := preload("res://assets/visual/reference_v1/legacy_mentor.webp")
const GOLD := Color("#f1c36e")
const GOLD_LIGHT := Color("#ffe1a0")
const INK := Color("#08111c")
const PAPER := Color("#f7f2e7")
const MUTED := Color("#c7ced8")

var focus: Control
var step_title := ""
var instruction := ""
var dialogue: PanelContainer
var font: Font
var _previous_rect := Rect2()
var _portrait_frame: PanelContainer


func _ready() -> void:
    name = "FirstCycleSpotlight"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    dialogue = PanelContainer.new()
    dialogue.name = "CoachDialogue"
    dialogue.mouse_filter = Control.MOUSE_FILTER_PASS
    dialogue.add_theme_stylebox_override("panel", _dialogue_style())
    dialogue.custom_minimum_size = Vector2(292, 118)
    add_child(dialogue)

    var inset := MarginContainer.new()
    inset.add_theme_constant_override("margin_left", 12)
    inset.add_theme_constant_override("margin_right", 12)
    inset.add_theme_constant_override("margin_top", 10)
    inset.add_theme_constant_override("margin_bottom", 11)
    dialogue.add_child(inset)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 8)
    inset.add_child(layout)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 7)
    layout.add_child(top)

    var accent := ColorRect.new()
    accent.custom_minimum_size = Vector2(3, 42)
    accent.color = GOLD
    top.add_child(accent)

    _portrait_frame = PanelContainer.new()
    _portrait_frame.custom_minimum_size = Vector2(46, 46)
    _portrait_frame.add_theme_stylebox_override("panel", _portrait_style())
    top.add_child(_portrait_frame)

    var portrait := TextureRect.new()
    portrait.texture = COACH
    portrait.custom_minimum_size = Vector2(42, 42)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _portrait_frame.add_child(portrait)

    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_theme_constant_override("separation", 3)
    top.add_child(copy)

    var identity := _label(copy, "관장  /  COACHING", 9, GOLD)
    identity.name = "CoachIdentity"
    identity.add_theme_font_override("font", UI_FONT())

    var heading_row := HBoxContainer.new()
    heading_row.add_theme_constant_override("separation", 4)
    copy.add_child(heading_row)

    var heading := _label(heading_row, step_title, 13, GOLD_LIGHT)
    heading.name = "TutorialStepTitle"
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if font != null:
        heading.add_theme_font_override("font", font)

    var skip := Button.new()
    skip.text = "건너뛰기"
    skip.name = "TutorialSkip"
    skip.flat = true
    skip.focus_mode = Control.FOCUS_NONE
    skip.add_theme_font_size_override("font_size", 10)
    skip.add_theme_color_override("font_color", MUTED)
    skip.pressed.connect(func(): skipped.emit())
    heading_row.add_child(skip)

    var separator := ColorRect.new()
    separator.custom_minimum_size = Vector2(0, 1)
    separator.color = Color("#394454")
    layout.add_child(separator)

    var guidance := _label(layout, instruction, 13, PAPER)
    guidance.name = "TutorialInstruction"
    guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    guidance.custom_minimum_size.y = 34
    if font != null:
        guidance.add_theme_font_override("font", font)

    call_deferred("_position_dialogue")


func UI_FONT() -> Font:
    return ThemeDB.fallback_font


func _dialogue_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0a1421f5")
    style.border_color = Color("#b78b4b")
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
    style.shadow_size = 18
    style.shadow_offset = Vector2(0, 5)
    return style


func _portrait_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#1a2635")
    style.border_color = Color("#d5a75e")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 2
    style.content_margin_right = 2
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    return style


func _label(parent: Control, value: String, size: int, color: Color) -> Label:
    var result := Label.new()
    result.text = value
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    if font != null:
        result.add_theme_font_override("font", font)
    parent.add_child(result)
    return result


func _process(_delta: float) -> void:
    if not is_instance_valid(focus):
        return
    var rect := _focus_rect()
    if rect != _previous_rect:
        _previous_rect = rect
        _position_dialogue()
        queue_redraw()


func _focus_rect() -> Rect2:
    if not is_instance_valid(focus) or not focus.is_visible_in_tree():
        return Rect2()
    var global := focus.get_global_rect()
    var local := Rect2(global.position - get_global_rect().position, global.size)
    return local.grow(7).intersection(Rect2(Vector2.ZERO, size))


func _position_dialogue() -> void:
    if not is_instance_valid(dialogue):
        return
    var rect := _focus_rect()
    var width := minf(310.0, size.x - 20.0)
    dialogue.size = Vector2(width, maxf(116.0, dialogue.get_combined_minimum_size().y))
    var height := dialogue.size.y
    var below := rect.size.y > 5.0 and rect.get_center().y < size.y * 0.48
    var y := size.y - height - 88.0 if below else 68.0
    y = clampf(y, 48.0, maxf(48.0, size.y - height - 66.0))
    var x := clampf(rect.get_center().x - width / 2.0, 10.0, size.x - width - 10.0) if rect.size.x > 5.0 else 10.0
    dialogue.position = Vector2(x, y)


func _draw() -> void:
    if not is_instance_valid(focus):
        return
    var rect := _focus_rect()
    if rect.size.x < 5.0 or rect.size.y < 5.0:
        return

    var dim := Color(0.008, 0.015, 0.026, 0.68)
    draw_rect(Rect2(0, 0, size.x, rect.position.y), dim)
    draw_rect(Rect2(0, rect.end.y, size.x, size.y - rect.end.y), dim)
    draw_rect(Rect2(0, rect.position.y, rect.position.x, rect.size.y), dim)
    draw_rect(Rect2(rect.end.x, rect.position.y, size.x - rect.end.x, rect.size.y), dim)

    draw_rect(rect.grow(9), Color(1.0, 0.69, 0.25, 0.055), false, 9.0)
    draw_rect(rect.grow(5), Color(1.0, 0.69, 0.25, 0.24), false, 2.0)
    draw_rect(rect, GOLD_LIGHT, false, 1.5)

    var length := minf(22.0, minf(rect.size.x, rect.size.y) * 0.22)
    var weight := 3.0
    var corners := [
        [rect.position, Vector2(1, 0), Vector2(0, 1)],
        [Vector2(rect.end.x, rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
        [Vector2(rect.position.x, rect.end.y), Vector2(1, 0), Vector2(0, -1)],
        [rect.end, Vector2(-1, 0), Vector2(0, -1)],
    ]
    for corner in corners:
        var origin: Vector2 = corner[0]
        var horizontal: Vector2 = corner[1]
        var vertical: Vector2 = corner[2]
        draw_line(origin, origin + horizontal * length, GOLD_LIGHT, weight, true)
        draw_line(origin, origin + vertical * length, GOLD_LIGHT, weight, true)
