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
const PRIMARY_IDS := ["heavy_bag", "defense_drill", "roadwork", "mitts"]
const SPARRING_IDS := ["sparring"]
const RECOVERY_IDS := ["full_rest", "rehab"]
const WEIGHT_IDS := ["weight_cut"]
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
var selected_action: Dictionary = {}
var card_frames: Dictionary = {}
var card_buttons: Dictionary = {}
var execute_button: Button

func _ready() -> void:
    name = "ReferenceTraining"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 12)

    if show_first_bout_guide:
        _coach_banner()
    _training_header()
    _condition_summary()
    _training_programs()
    _body_care()
    _execute_footer()

    if not show_first_bout_guide:
        var shop := _button("체육관 장비 투자  ›")
        shop.name = "TrainingUpgradeShop"
        shop.pressed.connect(func(): shop_requested.emit())
        add_child(shop)
        var media := _button("지역 팬 미팅 · 인기 +2")
        media.name = "ManagementMedia"
        media.pressed.connect(func(): media_requested.emit())
        add_child(media)


func _coach_banner() -> void:
    var frame := _panel(self, Color("#0b1724"), GOLD, 10)
    frame.name = "TrainingCoachBanner"
    var row := _row(frame, 10)
    var portrait := TextureRect.new()
    portrait.name = "TrainingCoachPortrait"
    portrait.texture = preload("res://assets/visual/reference_v1/legacy_mentor.webp")
    portrait.custom_minimum_size = Vector2(54, 54)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)
    var copy := _column(row, 4)
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var identity_row := _row(copy, 6)
    var identity := _label(identity_row, "관장  /  COACHING", 9, GOLD_BRIGHT, bold_font)
    identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var skip := Button.new()
    skip.name = "FirstBoutGuideSkip"
    skip.text = "건너뛰기"
    skip.flat = true
    skip.focus_mode = Control.FOCUS_NONE
    skip.add_theme_font_size_override("font_size", 10)
    skip.add_theme_color_override("font_color", MUTED)
    skip.pressed.connect(func(): guide_skipped.emit())
    identity_row.add_child(skip)
    var instruction := _label(copy, "첫 훈련이다. 네 몸 상태를 보고 훈련 하나를 골라봐.", 13, WHITE, bold_font)
    instruction.name = "TrainingCoachInstruction"
    instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _training_header() -> void:
    var header := _row(self, 8)
    header.name = "TrainingHeader"
    var copy := _column(header, 3)
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(copy, "CAMP  /  FIRST SESSION" if show_first_bout_guide else "CAMP  /  DEVELOPMENT", 9, GOLD_BRIGHT, bold_font)
    var title := _label(copy, "첫 훈련" if show_first_bout_guide else "훈련과 성장", 27, WHITE, heading_font)
    title.name = "TrainingPageTitle"
    _label(copy, "훈련 하나를 선택하세요." if show_first_bout_guide else "다음 경기를 위해 몸과 기술을 준비하세요.", 11, MUTED)
    var money := _panel(header, Color("#172536"), GOLD_DARK, 8)
    money.name = "TrainingMoneyBadge"
    var money_copy := _column(money, 2)
    _label(money_copy, "보유 파이트머니", 9, MUTED, bold_font)
    _label(money_copy, _money(int(GameState.state.get("career", {}).get("money", 0))) + "원", 15, GOLD_BRIGHT, heading_font)


func _condition_summary() -> void:
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var frame := _panel(self, Color("#0d1824"), Color("#34475b"), 8)
    frame.name = "TrainingConditionSummary"
    var row := _row(frame, 12)
    _condition_metric(row, "건강", "%d" % int(boxer.get("health", 100)), GREEN)
    _condition_metric(row, "피로", "%d" % int(boxer.get("fatigue", 0)), CYAN)
    _condition_metric(row, "체중", "%.1fkg" % float(boxer.get("weight_kg", 0.0)), WHITE)
    var injury: Dictionary = boxer.get("injury", {})
    _condition_metric(row, "부상", "없음" if injury.is_empty() else str(injury.get("name", "부상")), GREEN if injury.is_empty() else RED)


func _condition_metric(parent: HBoxContainer, caption: String, value: String, color: Color) -> void:
    var metric := _column(parent, 2)
    metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(metric, caption, 9, MUTED, bold_font)
    _label(metric, value, 13, color, heading_font)

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
    panel.add_theme_stylebox_override("panel", REFERENCE_UI.beveled_panel_style(background, edge, padding))
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
    var boxer: Dictionary = GameState.state["boxer"]
    var career: Dictionary = GameState.state["career"]
    var weight_name := str(GameState.career_balance["weight_class"].get("name", "체급 미정"))
    var stats := [
        {"id":"power", "label":"공격력"},
        {"id":"defense", "label":"수비력"},
        {"id":"conditioning", "label":"체력"},
        {"id":"technique", "label":"기술"},
        {"id":"speed", "label":"스피드"},
    ]
    var total := 0
    for stat in stats:
        total += int(boxer.get(str(stat.id), 0))
    var overall := roundi(float(total) / float(stats.size()))

    var frame := _panel(self, INK, GOLD_DARK, 3)
    frame.name = "TrainingHeroPanel"
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    frame.add_child(row)

    var portrait := TextureRect.new()
    portrait.name = "TrainingHeroPhoto"
    portrait.texture = HERO
    portrait.custom_minimum_size = Vector2(142, 208)
    portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)

    var info := _column(row, 4)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title := _label(info, "훈련 · 성장", 24, WHITE, heading_font)
    title.name = "TrainingTitle"
    var season := _label(info, "SEASON %d  ·  %s" % [1 + int(career.get("fights", 0)) / 4, str(GameState.career_ladder_stage().get("label", ""))], 9, GOLD_BRIGHT, bold_font)
    season.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var name_row := _row(info, 3)
    var fighter_name := _label(name_row, str(boxer.get("name", "복서")), 20, WHITE, heading_font)
    fighter_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(name_row, weight_name, 10, MUTED, bold_font)
    var score_row := _row(info, 5)
    var overall_panel := _panel(score_row, GOLD, GOLD_BRIGHT, 3)
    overall_panel.custom_minimum_size = Vector2(58, 64)
    var score_content := _column(overall_panel, 0)
    score_content.alignment = BoxContainer.ALIGNMENT_CENTER
    var score_caption := _label(score_content, "OVR", 10, INK, bold_font)
    score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var score := _label(score_content, str(overall), 25, INK, heading_font)
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var bars := _column(score_row, 3)
    bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for stat in stats:
        _stat_bar(bars, str(stat.label), int(boxer.get(str(stat.id), 0)))
    var subtitle := _label(info, "훈련으로 능력을 강화하고 다음 경기를 준비하세요.", 9, MUTED)
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _stat_bar(parent: VBoxContainer, caption: String, value: int) -> void:
    var row := _row(parent, 4)
    var name := _label(row, caption, 9, WHITE, bold_font)
    name.custom_minimum_size.x = 38
    var bar := ProgressBar.new()
    bar.min_value = 0
    bar.max_value = 100
    bar.value = clampi(value, 0, 100)
    bar.show_percentage = false
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.custom_minimum_size.y = 6
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_theme_stylebox_override("background", REFERENCE_UI.panel_style(Color("#26313d"), Color("#34414d"), 0))
    bar.add_theme_stylebox_override("fill", REFERENCE_UI.panel_style(GOLD, GOLD_BRIGHT, 0))
    row.add_child(bar)
    var amount := _label(row, str(value), 9, WHITE, bold_font)
    amount.custom_minimum_size.x = 20
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _condition_panel() -> void:
    var boxer: Dictionary = GameState.state["boxer"]
    var frame := _panel(self, Color("#0d1824"), GOLD_DARK, 7)
    frame.name = "TrainingConditionPanel"
    var content := _column(frame, 5)
    var title := _label(content, "컨디션 & 경기 준비", 15, GOLD_BRIGHT, heading_font)
    var row := _row(content, 10)
    var health := _column(row, 3)
    health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _meter(health, "TrainingHealthMeter", "건강", int(boxer.get("health", 100)), GREEN)
    _meter(health, "TrainingFatigueMeter", "피로도", int(boxer.get("fatigue", 0)), CYAN)
    var details := _column(row, 4)
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var limit := float(GameState.career_balance["weight_class"]["limit_kg"])
    _pair(details, "체중 / 기준", "%.1f / %.1f kg" % [float(boxer.get("weight_kg", 0.0)), limit])
    var injury: Dictionary = boxer.get("injury", {})
    _pair(details, "부상", str(injury.get("name", "없음")), GREEN if injury.is_empty() else RED)
    var readiness := "최상" if int(boxer.get("health", 100)) >= 85 and int(boxer.get("fatigue", 0)) <= 20 else ("양호" if int(boxer.get("health", 100)) >= 65 else "회복 필요")
    _label(details, "현재 상태 · " + readiness, 10, GOLD_BRIGHT, bold_font)

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
    var title := _label(row, "이번 캠프 · 훈련 1회", 15, GOLD_BRIGHT, heading_font)
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var note := _label(row, "기본 훈련은 무료입니다.\n장비에 투자하면 성장 효율이 높아집니다.", 10, WHITE)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _grid(node_name: String) -> GridContainer:
    var grid := GridContainer.new()
    grid.name = node_name
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 11)
    add_child(grid)
    return grid

func _training_programs() -> void:
    _section_heading("기술 · 체력 훈련", "TRAINING")
    var list := _list("TrainingPrimaryList")
    var ordered_ids := ["sparring"] + PRIMARY_IDS
    for id: String in ordered_ids:
        for action: Dictionary in actions:
            if str(action.get("id", "")) == id:
                _card(list, action, true)
                break


func _section_heading(title_text: String, eyebrow: String) -> void:
    var heading := _row(self, 4)
    var title := _label(heading, title_text, 18, GOLD_BRIGHT, heading_font)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(heading, eyebrow, 9, MUTED, bold_font)


func _list(node_name: String) -> VBoxContainer:
    var list := VBoxContainer.new()
    list.name = node_name
    list.add_theme_constant_override("separation", 10)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(list)
    return list

func _resources() -> void:
    var panel := _panel(self, Color("#0d1824"), GOLD_DARK, 8)
    panel.name = "TrainingResources"
    var content := _column(panel, 5)
    var title_row := _row(content, 5)
    var title := _label(title_row, "훈련 자원", 15, GOLD_BRIGHT, heading_font)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(title_row, "CAMP RESOURCES", 8, MUTED, bold_font)
    var values := _row(content, 7)
    _resource_metric(values, "보유 파이트머니", _money(int(GameState.state.get("career", {}).get("money", 0))) + "원")
    _resource_metric(values, "이번 캠프", "훈련 1회")
    _resource_metric(values, "선택 가능", "%d개" % actions.size())

func _resource_metric(parent: HBoxContainer, caption: String, value: String) -> void:
    var metric := VBoxContainer.new()
    metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    metric.add_theme_constant_override("separation", 2)
    parent.add_child(metric)
    _label(metric, caption, 9, MUTED, bold_font)
    _label(metric, value, 13, WHITE, heading_font)

func _execute_footer() -> void:
    # Keep the action reachable while the long training list scrolls.
    var clearance := Control.new()
    clearance.name = "TrainingBottomClearance"
    clearance.custom_minimum_size.y = 178
    add_child(clearance)

    var layer := CanvasLayer.new()
    layer.name = "TrainingActionLayer"
    layer.layer = 20
    add_child(layer)

    var dock := PanelContainer.new()
    dock.name = "TrainingActionDock"
    dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    dock.offset_left = 12
    dock.offset_right = -12
    dock.offset_top = -158
    dock.offset_bottom = -86
    dock.add_theme_stylebox_override("panel", REFERENCE_UI.beveled_panel_style(Color("#0a1420f5"), GOLD_DARK, 8))
    layer.add_child(dock)

    execute_button = _button("훈련을 선택하세요", true)
    execute_button.name = "TrainingExecute"
    execute_button.custom_minimum_size.y = 56
    execute_button.add_theme_font_size_override("font_size", 18)
    execute_button.disabled = true
    execute_button.pressed.connect(_execute_selected)
    dock.add_child(execute_button)

func _execute_selected() -> void:
    if selected_action.is_empty() or not is_instance_valid(execute_button) or execute_button.disabled:
        return
    execute_button.disabled = true
    for button_value in card_buttons.values():
        var button: Button = button_value
        button.disabled = true
    action_chosen.emit(selected_action)

func _body_care() -> void:
    _section_heading("회복 · 체중 관리", "RECOVERY")
    var help := _label(self, "컨디션과 계체 상황에 맞춰 필요한 관리를 선택하세요.", 11, MUTED)
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var list := _list("TrainingBodyCareList")
    for id: String in RECOVERY_IDS + WEIGHT_IDS:
        for action: Dictionary in actions:
            if str(action.get("id", "")) == id:
                _card(list, action, true)
                break

func _photo_for(id: String) -> Texture2D:
    match id:
        "sparring", "defense_drill": return SPARRING
        "roadwork", "weight_cut": return RUNNING
        "mitts", "heavy_bag": return BAG
        _: return REST

func _card(parent: Control, action: Dictionary, wide: bool = true) -> void:
    var id := str(action.get("id", ""))
    var cost := int(action.get("cost", 0))
    var affordable := int(GameState.state.get("career", {}).get("money", 0)) >= cost
    var frame := _panel(parent, Color("#101d2b"), GOLD_DARK, 7)
    frame.name = "TrainingCard_" + id
    frame.custom_minimum_size = Vector2(0, 154)
    card_frames[id] = frame

    var horizontal := HBoxContainer.new()
    horizontal.add_theme_constant_override("separation", 11)
    frame.add_child(horizontal)

    var photo_frame := PanelContainer.new()
    photo_frame.custom_minimum_size = Vector2(108, 138)
    photo_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    photo_frame.add_theme_stylebox_override("panel", _style(Color("#080f18"), Color("#566273"), 1))
    horizontal.add_child(photo_frame)
    var photo := TextureRect.new()
    photo.texture = _photo_for(id)
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    photo_frame.add_child(photo)

    var content := _column(horizontal, 5)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var heading := _row(content, 4)
    var name := _label(heading, action_title(action), 16, WHITE, heading_font)
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var price := _label(heading, "무료" if cost == 0 else _money(cost) + "원", 10, GOLD_BRIGHT, bold_font)
    price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    var description := _label(content, str(CARD_COPY.get(id, "")), 11, MUTED)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.max_lines_visible = 2
    description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

    var effects: Dictionary = action.get("effects", {}).duplicate(true)
    var tradeoffs := {}
    for key in ["fatigue", "weight", "injury_camps"]:
        if effects.has(key):
            tradeoffs[key] = effects[key]
            effects.erase(key)
    var effect_box := _column(_panel(content, Color("#0b1621"), Color("#45576a"), 5), 2)
    var summary_text := "   ·   ".join(effect_parts(effects))
    var summary := _label(effect_box, summary_text if not summary_text.is_empty() else "기본 효과", 10, GREEN, bold_font)
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var tradeoff_text := "   ·   ".join(effect_parts(tradeoffs))
    if not tradeoff_text.is_empty():
        var tradeoff_color := RED if float(tradeoffs.get("fatigue", 0)) > 0 else CYAN
        var tradeoff := _label(effect_box, tradeoff_text, 10, tradeoff_color, bold_font)
        tradeoff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var footer := _row(content, 6)
    var efficiency_text := ""
    if str(action.get("kind", "")) == "training":
        var efficiency := int(round(GameState.gym_training_percent(id)))
        efficiency_text = "성장 효율 +%d%%" % efficiency if efficiency > 0 else "기본 훈련 효율"
    var efficiency_label := _label(footer, efficiency_text, 9, GOLD_BRIGHT, bold_font)
    efficiency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var choose := _button("선택" if affordable else "잔액 부족", false)
    choose.name = "TrainingSelect_" + id
    choose.custom_minimum_size = Vector2(92, 34)
    choose.size_flags_horizontal = Control.SIZE_SHRINK_END
    choose.disabled = not affordable
    choose.pressed.connect(_select_action.bind(action, choose))
    footer.add_child(choose)
    card_buttons[id] = choose

func _select_action(action: Dictionary, button: Button) -> void:
    if button.disabled or is_queued_for_deletion():
        return
    selected_action = action.duplicate(true)
    var selected_id := str(selected_action.get("id", ""))
    for key in card_frames.keys():
        var frame: PanelContainer = card_frames[key]
        var selected := str(key) == selected_id
        frame.add_theme_stylebox_override("panel", REFERENCE_UI.beveled_panel_style(Color("#162535") if selected else PANEL, GOLD if selected else GOLD_DARK, 5))
        var card_button: Button = card_buttons[key]
        card_button.text = "선택됨" if selected else ("잔액 부족" if card_button.disabled else "선택")
        if selected:
            var selected_style := REFERENCE_UI.gold_button_style()
            card_button.add_theme_stylebox_override("normal", selected_style)
            card_button.add_theme_stylebox_override("hover", selected_style)
            card_button.add_theme_color_override("font_color", Color("#111a26"))
        else:
            card_button.add_theme_stylebox_override("normal", _style(PANEL, GOLD_DARK, 6))
            card_button.add_theme_stylebox_override("hover", _style(Color("#243243"), GOLD, 6))
            card_button.add_theme_color_override("font_color", GOLD_BRIGHT)
    if is_instance_valid(execute_button):
        execute_button.disabled = false
        execute_button.text = "%s 실행하기  ▶" % action_title(selected_action)

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

func _tip() -> void:
    var row := _row(_panel(self, PANEL, GOLD_DARK, 7), 10)
    var title := _label(row, "육성 팁", 14, GOLD_BRIGHT, heading_font)
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var note := _label(row, "돈으로 훈련 효율을 높이는 장비에 투자하세요.\n투자한 장비는 이후 훈련에도 적용됩니다.", 10)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
