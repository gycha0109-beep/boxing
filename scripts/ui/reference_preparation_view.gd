extends VBoxContainer

signal confirmed(preparation_id: String)
signal back_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const TACTICAL_ART := preload("res://assets/visual/reference_v1/tactical_art.png")
const TACTICAL_ART_ROWS := {"distance_drill": 0, "body_pattern": 1, "counter_timing": 2, "pressure_entry": 3}
const CONDITION_ART := {
    "full_rest": preload("res://assets/visual/reference_v1/training_rest.png"),
    "weight_control": preload("res://assets/visual/reference_v1/training_running.png"),
    "sharpness": preload("res://assets/visual/reference_v1/training_sparring.png"),
}
const INK := Color("#0a1420")
const NAVY := Color("#101e2c")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#c1cbd4")

var is_tactical := true
var boxer: Dictionary = {}
var opponent: Dictionary = {}
var boxer_portrait: Texture2D
var opponent_portrait: Texture2D
var opponent_details: String
var locked_tactic: String
var guide_tip := ""
var options: Array[Dictionary] = []
var bold_font: Font
var heading_font: Font
var _choices: Dictionary = {}
var _selected_id := ""
var _continue_button: Button

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _matchup()
    _instruction()
    for option in options:
        _option_card(option)
    _navigation()

func _matchup() -> void:
    var frame := _panel(self, INK, UI.GOLD_DARK, 5)
    frame.name = "V19TacticalMatchup" if is_tactical else "ConditionMatchup"
    var backdrop := Control.new()
    backdrop.clip_contents = true
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(backdrop)
    for right in [false, true]:
        var lighting := _picture(LIGHTS)
        backdrop.add_child(lighting)
        lighting.anchor_left = 0.67 if right else 0.0
        lighting.anchor_right = 1.0 if right else 0.33
        lighting.offset_bottom = 137.0
        lighting.flip_h = right
        lighting.modulate.a = 0.67

    var content := _column(frame, 3)
    var title := _label(content, "전술 준비" if is_tactical else "컨디션 준비", 29, PAPER, heading_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var badge := _panel(content, UI.GOLD, UI.GOLD_BRIGHT, 1)
    badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var subtitle := _label(badge, "FIGHT PLAN SELECTION" if is_tactical else "FIGHT WEEK", 15, INK, UI.DISPLAY_FONT)
    subtitle.custom_minimum_size.x = 162
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var matchup := _row(content, 6)
    var player := _fighter(matchup, boxer_portrait, "내 선수", str(boxer.get("name", "무명 복서")), Color("#744b42"))
    var condition := "건강 %d%% · 피로 %d%%\n체중 %.2fkg" % [
        int(boxer.get("health", 100)), int(boxer.get("fatigue", 0)), float(boxer.get("weight_kg", 0.0)),
    ]
    _label(player, condition, 11, MUTED)
    var versus := _label(matchup, "VS", 25, UI.GOLD_BRIGHT, UI.DISPLAY_FONT)
    versus.autowrap_mode = TextServer.AUTOWRAP_OFF
    versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var foe := _fighter(matchup, opponent_portrait, "다음 상대", str(opponent.get("name", "")), Color("#49657e"))
    _label(foe, opponent_details, 11, MUTED)
    var title_match := str(opponent.get("title_label", ""))
    if not title_match.is_empty():
        _label(foe, title_match, 10, UI.GOLD_BRIGHT, bold_font)

func _fighter(parent: HBoxContainer, portrait: Texture2D, caption: String, name_text: String, edge: Color) -> VBoxContainer:
    var side := _column(parent, 0)
    var picture := _picture(portrait)
    picture.custom_minimum_size.y = 111
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    side.add_child(picture)
    var panel := _panel(side, Color("#0e1a26"), edge, 5)
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var info := _column(panel, 1)
    _label(info, caption, 10, UI.GOLD_BRIGHT, bold_font)
    _label(info, name_text, 16, PAPER, bold_font)
    return info

func _instruction() -> void:
    var info := _column(_panel(self, NAVY, UI.GOLD_DARK, 6), 2)
    var title := "전술 1개 선택" if is_tactical else "경기 주간 준비 1개 선택"
    if not locked_tactic.is_empty():
        title += "  ·  전술 %s" % locked_tactic
    _label(info, title, 13, UI.GOLD_BRIGHT, bold_font)
    var caption := "영구 성장 없이 이번 경기에서 활용할 행동을 준비합니다." if is_tactical else "추가 영구 성장 없이 경기 당일 컨디션을 조정합니다."
    _label(info, caption, 11, PAPER)
    if not guide_tip.is_empty():
        var tip := _label(info, guide_tip, 12, UI.GOLD_BRIGHT, bold_font)
        tip.name = "FirstBoutPreparationGuide"

func _option_card(option: Dictionary) -> void:
    var id := str(option["id"])
    var frame := _panel(self, NAVY, UI.GOLD_DARK, 5)
    frame.name = "PreparationCard_" + id
    var row := _row(frame, 7)
    var art := _picture(_art_for(id))
    art.custom_minimum_size = Vector2(85, 63)
    art.clip_contents = true
    row.add_child(art)

    var content := _column(row, 2)
    _label(content, str(option["name"]), 16, PAPER, heading_font)
    _label(content, str(option["description"]), 11, PAPER)

    var effects_frame := _panel(row, INK, Color("#5c4b35"), 4)
    effects_frame.custom_minimum_size.x = 127
    effects_frame.size_flags_horizontal = Control.SIZE_FILL
    var effects := _column(effects_frame, 1)
    var caption := _label(effects, "주요 효과", 10, UI.GOLD_BRIGHT, bold_font)
    var delta := _label(effects, str(option["effect"]), 10, PAPER)
    delta.custom_minimum_size.x = 119

    # Let the content size the card and place one interactive target over it.
    var select := Button.new()
    select.name = "PreparationSelect_" + id
    select.accessibility_name = str(option["name"])
    select.tooltip_text = str(option["name"])
    select.toggle_mode = true
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "hover_pressed"]:
        select.add_theme_stylebox_override(state, empty)
    select.pressed.connect(_select.bind(id))
    frame.add_child(select)
    _choices[id] = {"frame": frame, "caption": caption, "button": select}

func _art_for(id: String) -> Texture2D:
    if not is_tactical:
        return CONDITION_ART.get(id)
    if not TACTICAL_ART_ROWS.has(id):
        return null
    var tile := AtlasTexture.new()
    tile.atlas = TACTICAL_ART
    tile.region = Rect2(0, 108 * int(TACTICAL_ART_ROWS[id]), 216, 108)
    tile.filter_clip = true
    return tile

func _select(id: String) -> void:
    if is_queued_for_deletion():
        return
    _selected_id = id
    for key in _choices:
        var item: Dictionary = _choices[key]
        var selected: bool = key == id
        var frame: PanelContainer = item["frame"]
        var caption: Label = item["caption"]
        var button: Button = item["button"]
        frame.add_theme_stylebox_override("panel", _choice_style(selected))
        caption.text = "선택됨 · 효과" if selected else "주요 효과"
        button.set_pressed_no_signal(selected)
    _continue_button.disabled = false

func _choice_style(selected: bool) -> StyleBoxFlat:
    if not selected:
        return UI.panel_style(NAVY, UI.GOLD_DARK, 5)
    var style := UI.panel_style(Color("#2c2316"), UI.GOLD_BRIGHT, 5)
    style.set_border_width_all(2)
    style.shadow_color = Color("#b27b2d78")
    style.shadow_size = 4
    return style

func _navigation() -> void:
    var row := _row(self, 7)
    var back := UI.action_button("← 상대 다시 선택" if is_tactical else "← 전술 준비 다시 선택", bold_font)
    back.name = "PreparationBack"
    back.pressed.connect(func():
        if not is_queued_for_deletion():
            back_requested.emit()
    )
    row.add_child(back)

    _continue_button = UI.action_button("컨디션 준비로  ›" if is_tactical else "게임플랜으로  ›", bold_font, true)
    _continue_button.name = "PreparationConfirm"
    _continue_button.size_flags_stretch_ratio = 1.18
    _continue_button.disabled = true
    _continue_button.pressed.connect(func():
        if not is_queued_for_deletion() and not _continue_button.disabled:
            confirmed.emit(_selected_id)
    )
    row.add_child(_continue_button)

func _panel(parent: Container, background: Color, edge: Color, margin: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.panel_style(background, edge, margin))
    parent.add_child(panel)
    return panel

func _column(parent: Control, separation: int) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", separation)
    parent.add_child(column)
    return column

func _row(parent: Control, separation: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", separation)
    parent.add_child(row)
    return row

func _label(parent: Control, text: String, size: int, color: Color, font: Font = null) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label

func _picture(texture: Texture2D) -> TextureRect:
    var picture := TextureRect.new()
    picture.texture = texture
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return picture
