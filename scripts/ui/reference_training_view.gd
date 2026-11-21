extends VBoxContainer

signal action_chosen(action: Dictionary)
signal shop_requested()
signal guide_skipped()
signal media_requested()

const REFERENCE_UI := preload("res://scripts/ui/reference_ui.gd")
const GOLD := REFERENCE_UI.GOLD
const GOLD_BRIGHT := REFERENCE_UI.GOLD_BRIGHT
const GOLD_DARK := REFERENCE_UI.GOLD_DARK
const WHITE := Color("#f7f4ec")
const MUTED := Color("#c1c9d1")
const CYAN := Color("#70c5ff")
const GREEN := Color("#8ae69d")
const RED := Color("#ef7e73")
const INK := Color("#0a1420")
const PANEL := Color("#101d2a")

const HERO := preload("res://assets/visual/reference_v1/training_hero.png")
const SPARRING := preload("res://assets/visual/reference_v1/training_sparring.png")
const RUNNING := preload("res://assets/visual/reference_v1/training_running.png")
const BAG := preload("res://assets/visual/reference_v1/training_bag.png")
const REST := preload("res://assets/visual/reference_v1/training_rest.png")
const PRIMARY_IDS := ["sparring", "roadwork", "mitts", "full_rest"]
const STAT_LABELS := {
    "power": "파워", "speed": "속도", "technique": "기술", "defense": "수비",
    "conditioning": "지구력", "health": "건강", "fatigue": "피로", "weight": "체중",
    "injury_camps": "부상 기간",
}
const CARD_COPY := {
    "sparring": "실전 감각과 기술을\n다듬는 스파링",
    "roadwork": "후반까지 버티는\n지구력 훈련",
    "mitts": "속도와 정확성을\n키우는 미트 훈련",
    "full_rest": "건강을 회복하고\n피로를 낮추는 휴식",
    "heavy_bag": "강한 펀치를\n만드는 타격 훈련",
    "defense_drill": "가드와 회피를\n익히는 수비 훈련",
    "rehab": "부상을 치료하고\n몸을 회복하는 재활",
    "weight_cut": "계체를 위한\n집중 체중 관리",
}

var actions: Array = []
var show_first_bout_guide := false
var heading_font: Font
var bold_font: Font
var _extras: GridContainer
var _toggle: Button

func _ready() -> void:
    name = "ReferenceTraining"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _hero()
    _camp_notice()
    _add_cards(_grid("TrainingPrimaryGrid"), true)
    _tip()
    _management()
    var shop := _button("장비 · 체육관 투자  ›")
    shop.pressed.connect(func(): shop_requested.emit())
    add_child(shop)
    var media := _button("지역 팬 미팅 · 인기 +2")
    media.name = "ManagementMedia"
    media.pressed.connect(func(): media_requested.emit())
    add_child(media)

static func action_title(action: Dictionary) -> String:
    match str(action.get("id", "")):
        "sparring": return "기본기 스파링"
        "roadwork": return "체력 러닝"
        "mitts": return "강펀치 미트"
        "full_rest": return "회복 휴식"
        _: return str(action.get("name", ""))

static func effect_parts(effects: Dictionary) -> Array[String]:
    var parts: Array[String] = []
    for stat in STAT_LABELS:
        if not effects.has(stat):
            continue
        var value := float(effects[stat])
        var amount := "%+.2fkg" % value if stat == "weight" else "%+d" % int(value)
        if stat == "injury_camps":
            amount += "캠프"
        parts.append("%s %s" % [STAT_LABELS[stat], amount])
    return parts

func _style(background: Color, edge: Color, padding: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = edge
    style.set_border_width_all(1)
    style.border_width_top = 2
    style.set_corner_radius_all(5)
    style.content_margin_left = padding
    style.content_margin_right = padding
    style.content_margin_top = padding
    style.content_margin_bottom = padding
    return style

func _panel(parent: Container, background: Color, edge: Color, padding: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(background, edge, padding))
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(panel)
    return panel

func _column(parent: Control, gap: int = 4) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", gap)
    parent.add_child(column)
    return column

func _row(parent: Control, gap: int = 6) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", gap)
    parent.add_child(row)
    return row

func _label(parent: Control, content: String, points: int, color: Color = WHITE, font: Font = null) -> Label:
    var label := Label.new()
    label.text = content
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    label.add_theme_constant_override("shadow_offset_y", 1)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label

func _photo(parent: PanelContainer, texture: Texture2D, start: float, end: float, top: float, bottom: float) -> TextureRect:
    # The backdrop doesn't affect minimum size or intercept taps.
    var backdrop := Control.new()
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.clip_contents = true
    parent.add_child(backdrop)
    var photo := TextureRect.new()
    photo.texture = texture
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.add_child(photo)
    photo.anchor_left = start
    photo.anchor_right = end
    photo.offset_top = top
    photo.anchor_bottom = 1.0
    photo.offset_bottom = bottom
    return photo

func _shade(photo: TextureRect, from: Vector2, to: Vector2, color: Color) -> void:
    var transparent := Color(color, 0.0)
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([transparent, color])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill_from = from
    texture.fill_to = to
    var shade := TextureRect.new()
    shade.texture = texture
    shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    photo.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _hero() -> void:
    var frame := _panel(self, INK, GOLD_DARK, 2)
    var portrait := _photo(frame, HERO, 0.0, 0.62, 1.0, 0.0)
    portrait.name = "TrainingHeroPhoto"
    _shade(portrait, Vector2(0.68, 0), Vector2(0.96, 0), INK)
    _shade(portrait, Vector2(0, 0.42), Vector2(0, 0.0), INK)
    _shade(portrait, Vector2(0, 0.84), Vector2(0, 1), INK)

    var hero := _column(frame, 1)
    var title := _label(hero, "커리어 관리", 31, WHITE, heading_font)
    title.name = "TrainingTitle"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var career: Dictionary = GameState.state["career"]
    var stage := str(GameState.career_ladder_stage().get("label", ""))
    var badge := _panel(hero, GOLD, GOLD_BRIGHT, 1)
    badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var subtitle := _label(badge, "시즌 %d · %s · %d번째 경기" % [1 + int(career.fights) / 4, stage, int(career.fights) + 1], 11, INK, bold_font)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.custom_minimum_size.x = 137
    var book: Dictionary = GameState.state.career_state
    var deal := str(GameState.League.CONTRACTS[book.contract].name) if book.has("signed_at") else "데뷔 계약"
    var terms := _label(hero, "%s · 인기 %d · %s %d%%" % [
        GameState.League.BACKGROUNDS[book.background].name, career.reputation, deal, roundi(float(book.purse_rate) * 100)
    ], 12, WHITE, bold_font)
    terms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)

    var row := _row(hero)
    row.custom_minimum_size.y = 155
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    var frame_right := _panel(row, Color("#0d1824ed"), GOLD_DARK, 6)
    frame_right.size_flags_stretch_ratio = 1.05
    frame_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var condition := _column(frame_right, 3)
    var heading := _label(condition, "선수 컨디션", 14, GOLD_BRIGHT, bold_font)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var boxer: Dictionary = GameState.state["boxer"]
    _meter(condition, "TrainingHealthMeter", "건강 (HP)", int(boxer.get("health", 100)), RED)
    _meter(condition, "TrainingFatigueMeter", "피로도", int(boxer.get("fatigue", 0)), CYAN)
    var limit := float(GameState.career_balance["weight_class"]["limit_kg"])
    _pair(condition, "체중 / 기준", "%.1f / %.1f kg" % [float(boxer.get("weight_kg", 0.0)), limit])
    var injury: Dictionary = boxer.get("injury", {})
    _pair(condition, "부상", str(injury.get("name", "없음")), GREEN if injury.is_empty() else RED)

func _meter(parent: VBoxContainer, meter_name: String, title: String, value: int, color: Color) -> void:
    _pair(parent, title, "%d / 100" % value)
    var meter := ProgressBar.new()
    meter.name = meter_name
    meter.value = value
    meter.show_percentage = false
    meter.custom_minimum_size.y = 6
    var track := StyleBoxFlat.new()
    track.bg_color = Color("#2b3744")
    track.set_corner_radius_all(2)
    var fill := track.duplicate() as StyleBoxFlat
    fill.bg_color = color
    meter.add_theme_stylebox_override("background", track)
    meter.add_theme_stylebox_override("fill", fill)
    parent.add_child(meter)

func _pair(parent: VBoxContainer, title: String, value: String, color: Color = WHITE) -> void:
    var row := _row(parent, 4)
    var label := _label(row, title, 10, MUTED)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var item := _label(row, value, 11, color, bold_font)
    item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _camp_notice() -> void:
    var row := _row(_panel(self, PANEL, GOLD, 7), 10)
    if show_first_bout_guide:
        var instructions := _column(row, 2)
        instructions.alignment = BoxContainer.ALIGNMENT_CENTER
        var title := _label(instructions, "첫 경기 1/4 · 훈련", 15, GOLD_BRIGHT, heading_font)
        title.name = "FirstBoutTrainingGuide"
        var copy := _label(instructions, "훈련이나 회복을 고른 뒤 몸의 변화를 확인하세요.", 12, WHITE)
        copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var skip := REFERENCE_UI.action_button("안내 건너뛰기", bold_font)
        skip.name = "FirstBoutGuideSkip"
        skip.size_flags_horizontal = Control.SIZE_SHRINK_END
        skip.pressed.connect(func(): guide_skipped.emit())
        row.add_child(skip)
        return
    var title := _label(row, "이번 캠프  1회 선택", 15, GOLD_BRIGHT, heading_font)
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var note := _label(row, "이번 경기에 쓸 관리 기회는 한 번입니다.\n활동을 마치면 경기 제안이 열립니다.", 10, WHITE)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _grid(node_name: String) -> GridContainer:
    var grid := GridContainer.new()
    grid.name = node_name
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    add_child(grid)
    return grid

func _add_cards(grid: GridContainer, primary: bool) -> void:
    if primary:
        for id in PRIMARY_IDS:
            for value: Dictionary in actions:
                if str(value.get("id", "")) == id:
                    _card(grid, value)
                    break
        return
    for action: Dictionary in actions:
        if str(action.get("id", "")) not in PRIMARY_IDS:
            _card(grid, action)

func _photo_for(id: String) -> Texture2D:
    match id:
        "sparring", "defense_drill": return SPARRING
        "roadwork", "weight_cut": return RUNNING
        "mitts", "heavy_bag": return BAG
        _: return REST

func _card(grid: GridContainer, action: Dictionary) -> void:
    var id := str(action.get("id", ""))
    var cost := int(action.get("cost", 0))
    var affordable := int(GameState.state["career"].get("money", 0)) >= cost
    var frame := _panel(grid, INK, GOLD_DARK, 6)
    frame.name = "TrainingCard_" + id
    var photo := _photo(frame, _photo_for(id), 0.28, 1.0, 0.0, -72.0)
    _shade(photo, Vector2(0.27, 0), Vector2(0.0, 0), INK)
    _shade(photo, Vector2(0, 0.64), Vector2(0, 1), INK)

    var content := _column(frame, 2)
    _label(content, action_title(action), 18, WHITE, heading_font)
    var description := _label(content, str(CARD_COPY.get(id, "")), 10, WHITE)
    description.custom_minimum_size.y = 29

    var effect_box := _column(_panel(content, Color("#080f18ee"), GOLD_DARK, 4), 1)
    var effects: Dictionary = action.get("effects", {}).duplicate()
    var tradeoffs := {}
    for key in ["fatigue", "weight", "injury_camps"]:
        if effects.has(key):
            tradeoffs[key] = effects[key]
            effects.erase(key)
    var summary := _label(effect_box, " · ".join(effect_parts(effects)), 10, RED if id == "weight_cut" else GREEN, bold_font)
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary.custom_minimum_size.y = 15
    var tradeoff := _label(effect_box, " · ".join(effect_parts(tradeoffs)), 10, RED if float(tradeoffs.get("fatigue", 0)) > 0 else CYAN, bold_font)
    tradeoff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label(content, "%s원  ·  추가 위험 %.1f%%" % [_money(cost), float(action.get("risk", 0.0)) * 100.0], 10, GOLD_BRIGHT)

    var choose := _button("선택" if affordable else "잔액 부족", true)
    choose.name = "TrainingSelect_" + id
    choose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    choose.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
    choose.custom_minimum_size.x = 134
    choose.disabled = not affordable
    choose.pressed.connect(_choose.bind(action, choose))
    content.add_child(choose)

func _money(amount: int) -> String:
    var raw := str(amount)
    var suffix := ""
    while raw.length() > 3:
        suffix = "," + raw.right(3) + suffix
        raw = raw.left(-3)
    return raw + suffix

func _button(text_value: String, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size.y = 56
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_font_override("font", heading_font if primary else bold_font)
    button.add_theme_color_override("font_color", Color("#18140c") if primary else GOLD_BRIGHT)
    button.add_theme_color_override("font_hover_color", Color("#18140c") if primary else WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#18140c") if primary else WHITE)
    button.add_theme_color_override("font_focus_color", Color("#18140c") if primary else GOLD_BRIGHT)
    if primary:
        var gold_style := REFERENCE_UI.gold_button_style()
        button.add_theme_stylebox_override("normal", gold_style)
        button.add_theme_stylebox_override("hover", gold_style)
        button.add_theme_stylebox_override("pressed", _style(GOLD_DARK, GOLD_BRIGHT, 6))
    else:
        button.add_theme_stylebox_override("normal", _style(PANEL, GOLD_DARK, 6))
        button.add_theme_stylebox_override("hover", _style(Color("#243243"), GOLD, 6))
        button.add_theme_stylebox_override("pressed", _style(INK, GOLD, 6))
    button.add_theme_stylebox_override("disabled", _style(Color("#25303c"), Color("#536170"), 6))
    return button

func _choose(action: Dictionary, button: Button) -> void:
    if not button.disabled and button.is_visible_in_tree() and not is_queued_for_deletion():
        action_chosen.emit(action)

func _management() -> void:
    _toggle = _button("다른 훈련 · 체중 · 재활  보기 ▼")
    _toggle.name = "TrainingMoreActions"
    _toggle.pressed.connect(_toggle_extras)
    add_child(_toggle)
    _extras = _grid("TrainingAdditionalActions")
    _extras.hide()
    _add_cards(_extras, false)

func _toggle_extras() -> void:
    _extras.visible = not _extras.visible
    _toggle.text = "다른 훈련 · 체중 · 재활  접기 ▲" if _extras.visible else "다른 훈련 · 체중 · 재활  보기 ▼"

func _tip() -> void:
    var row := _row(_panel(self, PANEL, GOLD_DARK, 7), 10)
    var title := _label(row, "캠프 팁", 14, GOLD_BRIGHT, heading_font)
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var note := _label(row, "경기 전에는 훈련으로 얻는 능력치와\n피로·체중 변화도 함께 확인하세요.", 10)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
