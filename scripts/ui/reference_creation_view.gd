extends VBoxContainer

signal style_chosen(style_id: String)
signal talent_confirmed()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const BALANCED_ART := preload("res://assets/visual/reference_v1/title_boxer.webp")
const TACTICAL_ART := preload("res://assets/visual/reference_v1/tactical_art.png")
const ACTION_ART := preload("res://assets/visual/reference_v1/battle_actions.png")
const TACTICAL_ROWS := {"out_boxer": 0, "counter_puncher": 2, "pressure_fighter": 3}
const STATS := {
    "power": "파워",
    "speed": "스피드",
    "technique": "테크닉",
    "defense": "수비",
    "conditioning": "체력",
}
const INK := Color("#09121b")
const PANEL := Color("#131c26")
const PAPER := Color("#f7f3e8")
const MUTED := Color("#c1cbd4")
const GREEN := Color("#9ddfa9")
const RED := Color("#f2a091")

var choosing_style := true
var styles: Array
var boxer: Dictionary
var talent: Dictionary
var heading_font: Font
var bold_font: Font

var _submitted := false

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 6)
    _masthead()
    if choosing_style:
        _style_picker()
    else:
        _talent_reveal()

func _masthead() -> void:
    var frame := _panel(self, UI.GOLD_DARK, 3)
    var art := Control.new()
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.clip_contents = true
    frame.add_child(art)
    for side in [0, 1]:
        var lamp := _picture(art, LIGHTS)
        lamp.anchor_left = 0.0 if side == 0 else 0.73
        lamp.anchor_right = 0.27 if side == 0 else 1.0
        lamp.anchor_bottom = 1.0
        lamp.flip_h = side == 1
        lamp.modulate.a = 0.59

    var stack := _column(frame, 1)
    var line := _row(stack, 5)
    line.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(line, 31, UI.GOLD, false)
    _label(line, "BOXER CREATION" if choosing_style else "NATURAL TALENT", 34, PAPER, UI.DISPLAY_FONT)
    Art.laurel(line, 31, UI.GOLD, true)
    var plaque := PanelContainer.new()
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    plaque.add_theme_stylebox_override("panel", Art.gold_plate(166, 25, Color("#c28b40"), 2))
    stack.add_child(plaque)
    var step := _label(plaque, "1 / 2   복싱 스타일 선택" if choosing_style else "2 / 2   타고난 재능", 13, INK, bold_font)
    step.custom_minimum_size = Vector2(162, 22)
    step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _style_picker() -> void:
    var guidance := _column(_panel(self), 0)
    _label(guidance, "스타일에 따라 시작 능력치가 달라집니다.", 13, UI.GOLD_BRIGHT, bold_font)
    _label(guidance, "이후 훈련을 통해 원하는 방향으로 키울 수 있습니다.", 11, MUTED)
    for style: Dictionary in styles:
        _style_card(style)

func _style_card(style: Dictionary) -> void:
    var id := str(style.get("id", ""))
    var card := _panel(self)
    var row := _row(card, 7)
    var thumbnail := _picture(row, _style_art(id))
    thumbnail.custom_minimum_size = Vector2(76, 74)

    var info := _column(row, 1)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(info, str(style.get("name", "")), 19, PAPER, heading_font)
    _label(info, str(style.get("signature", "")), 11, MUTED, null, true)
    var changes := _stat_changes(info, style.get("stat_bonus", {}))
    if changes.get_child_count() == 0:
        _label(changes, "시작 능력치 보정 없음", 10, MUTED, bold_font)

    var choose := _action("선택", 14, 48)
    choose.name = "BoxerStyle_" + id
    choose.custom_minimum_size.x = 73
    choose.size_flags_horizontal = Control.SIZE_SHRINK_END
    choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var hint := str(style.get("description", ""))
    choose.tooltip_text = str(style.get("name", "")) + " · " + hint
    choose.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            style_chosen.emit(id)
    )
    row.add_child(choose)

func _talent_reveal() -> void:
    var frame := _panel(self, UI.GOLD, 2)
    var scene := Control.new()
    scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene.clip_contents = true
    frame.add_child(scene)
    var arena_crop := AtlasTexture.new()
    arena_crop.atlas = RING
    arena_crop.region = Rect2(0, 0, 941, 465)
    arena_crop.filter_clip = true
    var image := _picture(scene, arena_crop)
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Art.glow(scene, Vector2(0.50, 0.81), Vector2(465, 167), Color(0.015, 0.025, 0.037, 0.97))
    Art.glow(scene, Vector2(0.50, 0.96), Vector2(292, 15), Color(1.0, 0.63, 0.25, 0.70))

    var nameplate := _column(frame, 0)
    nameplate.custom_minimum_size.y = 182
    nameplate.alignment = BoxContainer.ALIGNMENT_END
    var headline := _row(nameplate, 8)
    headline.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(headline, 35, UI.GOLD, false)
    var talent_name := str(talent.get("name", boxer.get("trait_name", "무특성")))
    var title := _label(headline, talent_name, 34, UI.GOLD_BRIGHT, heading_font)
    title.name = "BoxerTalentName"
    title.add_theme_color_override("font_outline_color", INK)
    title.add_theme_constant_override("outline_size", 7)
    Art.laurel(headline, 35, UI.GOLD, true)

    var details := _column(_panel(self), 3)
    _label(details, "재능 효과", 15, UI.GOLD_BRIGHT, heading_font)
    _label(details, str(talent.get("description", "이 선수만의 타고난 장단점입니다.")), 13, PAPER, null, true)
    _stat_changes(details, talent.get("stat_bonus", {}))
    _label(details, "이 선수의 재능은 커리어 동안 유지됩니다.", 11, MUTED)

    var stats := _column(_panel(self), 3)
    var heading := _row(stats, 5)
    var caption := _label(heading, "시작 능력치", 16, PAPER, heading_font)
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style_chip := _label(heading, "복싱 스타일   " + str(boxer.get("identity_name", "균형형")), 12, UI.GOLD_BRIGHT, bold_font)
    style_chip.name = "BoxerChosenStyle"
    style_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    for stat: String in STATS:
        _stat_meter(stats, stat)

    var begin := _action("이 복서로 커리어 시작  »", 21, 60)
    begin.name = "BoxerBeginCareer"
    begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    begin.custom_minimum_size.x = 318
    begin.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            talent_confirmed.emit()
    )
    add_child(begin)

func _stat_changes(parent: VBoxContainer, bonuses: Dictionary) -> HFlowContainer:
    var changes := HFlowContainer.new()
    changes.add_theme_constant_override("h_separation", 5)
    changes.add_theme_constant_override("v_separation", 0)
    parent.add_child(changes)
    for stat: String in STATS:
        var value := int(bonuses.get(stat, 0))
        if value != 0:
            var change := _label(changes, "%s %+d" % [STATS[stat], value], 10, GREEN if value > 0 else RED, bold_font)
            change.tooltip_text = "%s 시작 보정" % STATS[stat]
    return changes

func _stat_meter(parent: VBoxContainer, stat: String) -> void:
    var row := _row(parent, 7)
    var label := _label(row, STATS[stat], 12, MUTED, bold_font)
    label.custom_minimum_size.x = 54
    var amount := int(boxer.get(stat, 0))
    var meter := ProgressBar.new()
    meter.custom_minimum_size = Vector2(0, 6)
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.show_percentage = false
    meter.value = amount
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meter.add_theme_stylebox_override("background", UI.panel_style(Color("#253140"), Color("#34404e"), 0))
    meter.add_theme_stylebox_override("fill", UI.panel_style(Color("#c5914d"), UI.GOLD, 0))
    row.add_child(meter)
    var value := _label(row, str(amount), 13, PAPER, bold_font)
    value.name = "BoxerStat_" + stat
    value.custom_minimum_size.x = 24
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style_art(id: String) -> Texture2D:
    if id in TACTICAL_ROWS:
        var art := AtlasTexture.new()
        art.atlas = TACTICAL_ART
        art.region = Rect2(0, int(TACTICAL_ROWS[id]) * 108, 216, 108)
        art.filter_clip = true
        return art
    if id == "slugger":
        var art := AtlasTexture.new()
        art.atlas = ACTION_ART
        art.region = Rect2(150, 0, 150, 145)
        art.filter_clip = true
        return art
    return BALANCED_ART

func _action(text: String, size: int, height: int) -> Button:
    var button := UI.action_button(text, heading_font, true)
    button.custom_minimum_size.y = height
    button.add_theme_font_size_override("font_size", size)
    for state in ["normal", "hover", "pressed"]:
        var tone := Color("#ca9043")
        if state == "hover":
            tone = Color("#e2ab5b")
        elif state == "pressed":
            tone = Color("#9e652c")
        button.add_theme_stylebox_override(state, Art.gold_plate(146, height, tone, 3))
    return button

func _panel(parent: Container, edge: Color = UI.GOLD_DARK, padding: int = 6) -> PanelContainer:
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

func _picture(parent: Control, texture: Texture2D) -> TextureRect:
    var picture := TextureRect.new()
    picture.texture = texture
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(picture)
    return picture

func _label(parent: Control, text: String, size: int, color: Color, font: Font = null, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", size)
    if font != null:
        label.add_theme_font_override("font", font)
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label
