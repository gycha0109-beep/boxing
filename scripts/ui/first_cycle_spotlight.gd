extends Control

signal skipped()

const UI := preload("res://scripts/ui/reference_ui.gd")
const COACH := preload("res://assets/visual/reference_v1/legacy_mentor.webp")
const GOLD := Color("#ffd07b")
const MUTED := Color("#f7f2e7")

var focus: Control
var step_title := ""
var instruction := ""
var dialogue: PanelContainer
var font: Font
var _previous_rect := Rect2()


func _ready() -> void:
    name = "FirstCycleSpotlight"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dialogue = PanelContainer.new()
    dialogue.name = "CoachDialogue"
    dialogue.mouse_filter = Control.MOUSE_FILTER_PASS
    dialogue.add_theme_stylebox_override("panel", UI.beveled_panel_style(Color("#121d2bef"), GOLD, 7))
    dialogue.custom_minimum_size = Vector2(268, 88)
    add_child(dialogue)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 7)
    dialogue.add_child(row)
    var portrait := TextureRect.new()
    portrait.texture = COACH
    portrait.custom_minimum_size.x = 68
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_theme_constant_override("separation", 4)
    row.add_child(copy)
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 2)
    copy.add_child(head)
    var heading := _label(head, step_title, 12, GOLD)
    heading.name = "TutorialStepTitle"
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var skip := Button.new()
    skip.text = "건너뛰기"
    skip.name = "TutorialSkip"
    skip.flat = true
    skip.add_theme_font_size_override("font_size", 10)
    skip.pressed.connect(func(): skipped.emit())
    head.add_child(skip)
    var guidance := _label(copy, instruction, 12, MUTED)
    guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue.set_deferred("size", Vector2(296, 92))
    call_deferred("_position_dialogue")


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
    return local.grow(5).intersection(Rect2(Vector2.ZERO, size))


func _position_dialogue() -> void:
    if not is_instance_valid(dialogue):
        return
    var rect := _focus_rect()
    var width := minf(296.0, size.x - 18.0)
    dialogue.size = Vector2(width, maxf(98.0, dialogue.get_combined_minimum_size().y))
    var height := dialogue.size.y
    var y := 76.0
    if rect.size.y > 5.0:
        # Anchor coaching to the opposite screen region from the selected control.
        # The old placement immediately beside the card concealed neighbouring choices.
        y = 76.0 if rect.get_center().y > size.y * 0.40 else size.y - height - 95.0
    y = clampf(y, 48.0, maxf(48.0, size.y - height - 70.0))
    var x := clampf(rect.get_center().x - width / 2.0, 9.0, size.x - width - 9.0) if rect.size.x > 5.0 else 9.0
    dialogue.position = Vector2(x, y)


func _draw() -> void:
    if not is_instance_valid(focus):
        return
    var rect := _focus_rect()
    if rect.size.x < 5 or rect.size.y < 5:
        return
    var background := Color(0.015, 0.025, 0.045, 0.47)
    draw_rect(Rect2(0, 0, size.x, rect.position.y), background)
    draw_rect(Rect2(0, rect.end.y, size.x, size.y - rect.end.y), background)
    draw_rect(Rect2(0, rect.position.y, rect.position.x, rect.size.y), background)
    draw_rect(Rect2(rect.end.x, rect.position.y, size.x - rect.end.x, rect.size.y), background)
    draw_rect(rect.grow(4), Color(1.0, 0.68, 0.20, 0.21), false, 8.0)
    draw_rect(rect, GOLD, false, 3.0)
