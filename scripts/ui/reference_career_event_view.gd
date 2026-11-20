extends VBoxContainer

signal continue_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const EVENT_ART := {
    "local_sponsor": preload("res://assets/visual/reference_v1/legacy_trophy.webp"),
    "gym_fee": preload("res://assets/visual/reference_v1/training_bag.png"),
    "quiet_week": preload("res://assets/visual/reference_v1/training_rest.png"),
    "hand_soreness": preload("res://assets/visual/reference_v1/training_sparring.png"),
    "family_support": preload("res://assets/visual/reference_v1/legacy_mentor.webp"),
}
const INK := Color("#0b121a")
const PANEL := Color("#16212d")
const PAPER := Color("#f7f3e8")
const MUTED := Color("#bfc8ce")
const GREEN := Color("#a2df9c")
const RED := Color("#f39d8d")

var event: Dictionary
var before: Dictionary
var projected: Dictionary
var heading_font: Font
var bold_font: Font
var money_text: Callable

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _hero()
    _effects()

    var next := UI.action_button("계속", heading_font, true)
    next.name = "CareerEventContinue"
    next.custom_minimum_size = Vector2(285, 58)
    next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    next.add_theme_font_size_override("font_size", 22)
    next.add_theme_stylebox_override("normal", Art.gold_plate(285, 58, Color("#c78c3d"), 3))
    next.add_theme_stylebox_override("hover", Art.gold_plate(285, 58, Color("#e0ad54"), 3))
    next.add_theme_stylebox_override("pressed", Art.gold_plate(285, 58, Color("#9f652d"), 3))
    next.pressed.connect(func():
        if not next.disabled and not is_queued_for_deletion():
            next.disabled = true
            continue_requested.emit()
    )
    add_child(next)

func _hero() -> void:
    var frame := _panel(self, UI.GOLD_DARK, 3)
    var layer := Control.new()
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.clip_contents = true
    frame.add_child(layer)
    var image := TextureRect.new()
    image.texture = EVENT_ART.get(str(event.get("id", "")), RING)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    image.modulate = Color("#b5bfcb")
    layer.add_child(image)
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Art.glow(layer, Vector2(0.5, 0.13), Vector2(493, 149), Color(0.02, 0.035, 0.055, 0.86))
    Art.glow(layer, Vector2(0.5, 0.90), Vector2(510, 170), Color(0.02, 0.025, 0.033, 0.91))

    var content := _column(frame, 2)
    var banner := _row(content, 6)
    banner.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(banner, 34, UI.GOLD, false)
    var masthead := _label(banner, "CAREER EVENT", 38, PAPER, UI.DISPLAY_FONT)
    _outline(masthead)
    Art.laurel(banner, 34, UI.GOLD, true)

    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.custom_minimum_size.y = 104
    content.add_child(spacer)

    var title := _label(content, str(event.get("name", "커리어 소식")), 28, UI.GOLD_BRIGHT, heading_font)
    title.name = "CareerEventTitle"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _outline(title)
    var text_panel := _column(_panel(self), 2)
    var story := _label(text_panel, str(event.get("text", "")), 14, PAPER)
    story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _effects() -> void:
    var panel := _column(_panel(self), 4)
    _label(panel, "이벤트 적용 후", 16, UI.GOLD_BRIGHT, heading_font)
    var effects: Dictionary = event.get("effects", {})
    _add_effect(panel, effects, "money", "career", "보유금", &"money")
    _add_effect(panel, effects, "reputation", "career", "인지도", &"rank")
    _add_effect(panel, effects, "health", "boxer", "건강", &"condition")
    _add_effect(panel, effects, "fatigue", "boxer", "피로", &"speed", false)
    if effects.has("injury"):
        var injury: Dictionary = projected.get("boxer", {}).get("injury", {})
        if str(injury.get("id", "")) == str(effects["injury"]):
            var row := _effect_row(panel, "부상", &"injury")
            _label(row, str(injury.get("name", "")), 13, RED, bold_font)
    if panel.get_child_count() == 1:
        _label(panel, "상태 변동 없음", 12, MUTED)
    elif effects.has("health") or effects.has("fatigue") or effects.has("injury"):
        _label(panel, "다음 캠프의 회복은 캠프 진입 시 반영됩니다.", 11, MUTED)

func _add_effect(parent: VBoxContainer, effects: Dictionary, key: String, model: String, caption: String, icon: StringName, higher_is_better: bool = true) -> void:
    if not effects.has(key):
        return
    var old := int(before[model].get(key, 0))
    var new := int(projected[model].get(key, 0))
    var change := new - old
    var row := _effect_row(parent, caption, icon)
    _label(row, "%s  →  %s" % [_formatted(key, old), _formatted(key, new)], 13, PAPER, bold_font)
    var color := MUTED if change == 0 else (GREEN if (change > 0) == higher_is_better else RED)
    var delta := "변동 없음" if change == 0 else (("+" if change > 0 else "") + _formatted(key, change))
    var badge := _label(row, delta, 13, color, bold_font)
    badge.name = "CareerEventDelta_" + key
    badge.custom_minimum_size.x = 66
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _formatted(key: String, amount: int) -> String:
    if key == "money":
        return "%s원" % money_text.call(amount)
    return str(amount) + ("%" if key in ["health", "fatigue"] else "")

func _effect_row(parent: VBoxContainer, caption: String, icon: StringName) -> HBoxContainer:
    var divider := ColorRect.new()
    divider.color = Color("#9b784d71")
    divider.custom_minimum_size.y = 1
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(divider)
    var row := _row(parent, 6)
    Art.result_icon(row, icon)
    var text := _label(row, caption, 12, UI.GOLD_BRIGHT, bold_font)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return row

func _outline(label: Label) -> void:
    label.add_theme_color_override("font_outline_color", INK)
    label.add_theme_constant_override("outline_size", 6)

func _panel(parent: Container, edge: Color = UI.GOLD_DARK, padding: int = 8) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL, edge, padding))
    parent.add_child(panel)
    return panel

func _column(parent: Control, gap: int) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", gap)
    parent.add_child(column)
    return column

func _row(parent: Control, gap: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", gap)
    parent.add_child(row)
    return row

func _label(parent: Control, text: String, size: int, color: Color, font: Font = null) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label
