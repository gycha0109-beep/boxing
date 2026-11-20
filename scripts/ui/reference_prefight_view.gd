extends VBoxContainer

signal plan_chosen(id: String)
signal back_requested()
signal opponent_back_requested()
signal fight_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const SCOUTING_HAN := preload("res://assets/visual/reference_v1/scouting_han.png")
const SCOUTING_PLAYER := preload("res://assets/visual/reference_v1/profile_boxer.png")
const INK := Color("#0a1420")
const NAVY := Color("#101e2c")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#c1cbd4")
const RED := Color("#e2766d")
const BLUE := Color("#69bdf6")
const GREEN := Color("#8ae69d")

var weighing := false
var player: Dictionary
var opponent: Dictionary
var player_photo: Texture2D
var opponent_photo: Texture2D
var opponent_details: String
var analysis: Dictionary
var tendencies: Dictionary
var difficulty: String
var opponent_country: String
var comparison: Array[Dictionary] = []
var plans: Array[Dictionary] = []
var weigh: Dictionary
var weight_class: Dictionary
var confirmed_plan: Dictionary
var allow_plan_back := false
var heading_font: Font
var bold_font: Font
var _report_page: VBoxContainer
var _plan_page: VBoxContainer

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    if weighing:
        _weigh_in()
    else:
        _scouting()

func _scouting() -> void:
    _report_page = _column(self, 7)
    _scouting_heading()
    _opponent_card()
    _tendency_strip()
    _scouting_report()
    _comparison()

    var nav := _row(_report_page, 7)
    _action(nav, "← 컨디션 다시 선택", false, func(): back_requested.emit())
    var view_plans := _action(nav, "게임플랜 선택  ›", true, _show_plans.bind(true))
    view_plans.name = "ScoutingShowPlans"
    view_plans.size_flags_stretch_ratio = 1.65

    _plan_page = _column(self, 7)
    _plan_page.name = "ScoutingPlans"
    _game_plans(_plan_page)
    _plan_page.hide()

func _scouting_heading() -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    _report_page.add_child(panel)
    _add_lights(panel, 76.0)
    var content := _column(panel, 2)
    var title := _label(content, "OPPONENT SCOUTING", 34, PAPER, UI.DISPLAY_FONT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var tab := _scout_panel(content, Color("#c49346"), UI.GOLD_BRIGHT, 2)
    tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var caption := _label(tab, "상대 분석", 16, Color("#0b1119"), heading_font)
    caption.custom_minimum_size.x = 157
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _opponent_card() -> void:
    var card := _scout_panel(_report_page, INK, UI.GOLD_BRIGHT, 7)
    var row := _row(card, 7)
    var portrait := _crop_photo(_scouting_opponent_photo(), Vector2(149, 163))
    row.add_child(portrait)
    var info := _column(row, 3)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var top := _row(info, 4)
    var name_label := _label(top, "%s %s" % [str(opponent["name"]), opponent_country], 17, PAPER, heading_font)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var tint := GREEN if difficulty == "낮음" else RED if difficulty == "높음" else UI.GOLD
    var level := _scout_panel(top, INK.lerp(tint, 0.13), tint, 3)
    level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    level.size_flags_horizontal = Control.SIZE_FILL
    _label(level, "난이도 " + difficulty, 10, tint, bold_font).autowrap_mode = TextServer.AUTOWRAP_OFF
    var meta := _scout_panel(info, INK, UI.GOLD_DARK, 4)
    _label(meta, opponent_details, 10, PAPER)
    var opponent_title := str(opponent.get("title_label", ""))
    if not opponent_title.is_empty():
        _label(info, opponent_title, 10, UI.GOLD_BRIGHT, bold_font)

    var stats := _column(_scout_panel(info, INK, UI.GOLD_DARK, 4), 2)
    _label(stats, "핵심 능력치", 11, UI.GOLD_BRIGHT, bold_font)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 5)
    grid.add_theme_constant_override("v_separation", 1)
    stats.add_child(grid)
    for stat in comparison:
        var line := _row(grid, 3)
        line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var title := _label(line, str(stat["name"]), 9, PAPER)
        title.custom_minimum_size.x = 26
        _meter(line, int(stat["opponent"]), RED, false)

func _scouting_opponent_photo() -> Texture2D:
    if str(opponent.get("id", "")) == "han_do-yun":
        return SCOUTING_HAN
    return opponent_photo

func _tendency_strip() -> void:
    if tendencies.is_empty():
        return
    var row := _row(_scout_panel(_report_page, NAVY, UI.GOLD_DARK, 5), 3)
    var heading := _column(row, 0)
    _label(heading, "주요 액션", 10, UI.GOLD_BRIGHT, bold_font).autowrap_mode = TextServer.AUTOWRAP_OFF
    _label(heading, "기본 비중", 9, MUTED).autowrap_mode = TextServer.AUTOWRAP_OFF
    var names := {"jab": "잽", "body": "바디", "power": "강타", "guard": "가드", "counter": "카운터"}
    var colors := [UI.GOLD, Color("#deb3ae"), RED, BLUE, Color("#c0a4e7")]
    var index := 0
    for id in names:
        var chip := _scout_panel(row, INK.lerp(colors[index], 0.08), colors[index].darkened(0.38), 3)
        var labels := _column(chip, 0)
        var name_label := _label(labels, names[id], 9, PAPER, bold_font)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var percent := _label(labels, "%d%%" % roundi(float(tendencies.get(id, 0.0)) * 100.0), 12, colors[index], heading_font)
        percent.name = "ScoutingTendency_" + id
        percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        index += 1

func _scouting_report() -> void:
    var report := _column(_scout_panel(_report_page, INK, UI.GOLD_DARK, 5), 4)
    _report_row(report, "강점", str(analysis.get("strength", "정보 없음")), Color("#e49370"))
    _report_row(report, "약점", str(analysis.get("weakness", "정보 없음")), BLUE)
    _report_row(report, "버릇", str(analysis.get("tell", "정보 없음")), Color("#c0a4e7"))
    var recommended: Array[String] = []
    for plan in plans:
        if bool(plan["recommended"]):
            recommended.append(str(plan["name"]))
    if not recommended.is_empty():
        _report_row(report, "추천 대응", " / ".join(recommended), UI.GOLD_BRIGHT)

func _report_row(parent: VBoxContainer, title: String, value: String, color: Color) -> void:
    var line := _row(_panel(parent, Color("#101b27"), Color("#26333e"), 2), 6)
    var chip := _scout_panel(line, INK.lerp(color, 0.18), color.darkened(0.36), 4)
    chip.custom_minimum_size = Vector2(89, 31)
    chip.size_flags_horizontal = Control.SIZE_FILL
    var caption := _label(chip, title, 14, color, heading_font)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var detail := _label(line, value, 11, PAPER)
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _comparison() -> void:
    var frame := _scout_panel(_report_page, INK, UI.GOLD_DARK, 6)
    frame.name = "ScoutingComparison"
    var box := _column(frame, 2)
    var title := _label(box, "주요 능력치 비교", 13, UI.GOLD_BRIGHT, bold_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var columns := _row(box, 4)
    var player_crop := AtlasTexture.new()
    player_crop.atlas = SCOUTING_PLAYER
    player_crop.region = Rect2(0, 0, 361, 408)
    _comparison_portrait(columns, player_crop, "내 선수", str(player["name"]), RED)
    var bars := _column(columns, 1)
    bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for stat in comparison:
        var line := _row(bars, 3)
        _meter(line, int(stat["player"]), RED, true)
        var label := _label(line, str(stat["name"]), 9, UI.GOLD_BRIGHT, bold_font)
        label.custom_minimum_size.x = 34
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _meter(line, int(stat["opponent"]), BLUE, false)
    _comparison_portrait(columns, _scouting_opponent_photo(), "상대", str(opponent["name"]), BLUE)
    var condition := _label(box, "체중 %.2fkg  ·  피로 %d%%  ·  건강 %d%%" % [
        float(player["weight_kg"]), int(player["fatigue"]), int(player["health"]),
    ], 10, MUTED)
    condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _comparison_portrait(parent: HBoxContainer, texture: Texture2D, role: String, fighter_name: String, color: Color) -> void:
    var side := _column(parent, 1)
    side.custom_minimum_size.x = 71
    side.add_child(_crop_photo(texture, Vector2(71, 63)))
    var caption := _label(side, "%s · %s" % [role, fighter_name], 9, color, bold_font)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _crop_photo(texture: Texture2D, minimum: Vector2) -> TextureRect:
    var portrait := _photo(texture, int(minimum.y))
    portrait.custom_minimum_size.x = minimum.x
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    return portrait

func _scout_panel(parent: Container, background: Color, edge: Color, padding: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(background, edge, padding))
    parent.add_child(panel)
    return panel

func _meter(parent: HBoxContainer, value: int, fill_color: Color, from_right: bool) -> HBoxContainer:
    var row := _row(parent, 4)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var number := _label(row, str(value), 11, PAPER, bold_font)
    number.custom_minimum_size.x = 21
    number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var meter := ProgressBar.new()
    meter.max_value = 100.0
    meter.value = value
    meter.show_percentage = false
    meter.fill_mode = ProgressBar.FILL_END_TO_BEGIN if from_right else ProgressBar.FILL_BEGIN_TO_END
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.custom_minimum_size.y = 5
    meter.add_theme_stylebox_override("background", UI.panel_style(Color("#273442"), Color("#273442"), 0))
    meter.add_theme_stylebox_override("fill", UI.panel_style(fill_color, fill_color, 0))
    row.add_child(meter)
    if not from_right:
        row.move_child(number, 1)
    return row

func _game_plans(parent: VBoxContainer) -> void:
    var heading := _label(parent, "게임플랜 선택", 23, PAPER, heading_font)
    heading.name = "GamePlanHeading"
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    parent.add_child(grid)
    for plan in plans:
        var id := str(plan["id"])
        var is_recommended := bool(plan["recommended"])
        var card := _column(_panel(grid, NAVY, UI.GOLD_BRIGHT if is_recommended else UI.GOLD_DARK, 7), 3)
        _label(card, str(plan["name"]), 17, PAPER, heading_font)
        var tags := "위험도 %s" % str(plan["risk"])
        if is_recommended:
            tags = "추천  ·  " + tags
        _label(card, tags, 11, UI.GOLD_BRIGHT if is_recommended else MUTED, bold_font)
        var impact := _label(card, str(plan["effect"]), 11, MUTED)
        impact.size_flags_vertical = Control.SIZE_EXPAND_FILL
        var button := _action(card, "이 플랜 선택", is_recommended, func(): plan_chosen.emit(id))
        button.name = "GamePlanSelect_" + id
    var nav := _row(parent, 7)
    _action(nav, "← 상대 분석", false, _show_plans.bind(false))
    _action(nav, "← 상대 다시 선택", false, func(): opponent_back_requested.emit())
    _action(parent, "← 컨디션 다시 선택", false, func(): back_requested.emit())

func _show_plans(show_plans: bool) -> void:
    _report_page.visible = not show_plans
    _plan_page.visible = show_plans
    var scroll := find_parent("V17ContentScroll") as ScrollContainer
    if scroll != null:
        scroll.set_deferred("scroll_vertical", 0)
func _weigh_in() -> void:
    var hero := _banner("공식 계체", "OFFICIAL WEIGH-IN")
    var matchup := _row(hero, 7)
    _weigh_fighter(matchup, player_photo, str(player["name"]), "내 선수", RED)
    _weigh_fighter(matchup, opponent_photo, str(opponent["name"]), "다음 상대", BLUE)

    var limit := float(weight_class["limit_kg"])
    var scale := _row(_panel(self, NAVY, UI.GOLD_DARK, 8), 7)
    var measured := _column(scale, 1)
    measured.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(measured, "선수 계체", 11, MUTED, bold_font)
    var weight := _label(measured, "%.2f kg" % float(player["weight_kg"]), 31, PAPER, heading_font)
    weight.name = "WeighInWeight"
    var regulation := _column(scale, 1)
    regulation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(regulation, str(weight_class["name"]), 12, UI.GOLD_BRIGHT, bold_font)
    _label(regulation, "체중 제한 %.1f kg" % limit, 17, UI.GOLD_BRIGHT, bold_font)

    var verdict_color: Color = weigh["color"]
    var verdict := _column(_panel(self, INK, verdict_color, 8), 3)
    var outcome := _label(verdict, str(weigh["label"]), 21, verdict_color, heading_font)
    outcome.name = "WeighInVerdict"
    _label(verdict, str(weigh["detail"]), 12, PAPER)
    _label(verdict, "건강 %d%%  ·  피로 %d%%" % [int(player["health"]), int(player["fatigue"])], 11, MUTED)
    var plan := _column(_panel(self, NAVY, UI.GOLD_DARK, 8), 2)
    _label(plan, "확정된 게임플랜", 11, UI.GOLD_BRIGHT, bold_font)
    _label(plan, str(confirmed_plan.get("name", "균형 운영")), 19, PAPER, heading_font)
    _label(plan, str(confirmed_plan.get("description", "")), 11, MUTED)

    var nav := _row(self, 7)
    if allow_plan_back:
        _action(nav, "← 게임플랜 다시 선택", false, func(): back_requested.emit())
    var enter := _action(nav, "FIGHT NIGHT 입장", true, func(): fight_requested.emit())
    enter.name = "WeighInEnterFight"
    enter.size_flags_stretch_ratio = 1.18

func _weigh_fighter(row: HBoxContainer, portrait: Texture2D, fighter_name: String, caption: String, color: Color) -> void:
    var col := _column(row, 0)
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(_photo(portrait, 202))
    var info := _column(_panel(col, INK, color, 6), 1)
    info.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _label(info, caption, 10, color, bold_font)
    _label(info, fighter_name, 17, PAPER, heading_font)

func _banner(title: String, subtitle: String) -> VBoxContainer:
    var panel := _panel(self, INK, UI.GOLD_DARK, 4)
    _add_lights(panel, 106.0)
    var body := _column(panel, 3)
    var heading := _label(body, title, 27, PAPER, heading_font)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var plaque := _panel(body, UI.GOLD, UI.GOLD_BRIGHT, 1)
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var caption := _label(plaque, subtitle, 17, INK, UI.DISPLAY_FONT)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.custom_minimum_size.x = 160
    return body

func _add_lights(panel: PanelContainer, height: float) -> void:
    var backdrop := Control.new()
    backdrop.clip_contents = true
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(backdrop)
    for right in [false, true]:
        var lamps := _photo(LIGHTS, 0)
        lamps.stretch_mode = TextureRect.STRETCH_SCALE
        lamps.flip_h = right
        lamps.modulate.a = 0.75
        backdrop.add_child(lamps)
        lamps.anchor_left = 0.67 if right else 0.0
        lamps.anchor_right = 1.0 if right else 0.33
        lamps.offset_bottom = height

func _panel(parent: Container, background: Color, edge: Color, padding: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.panel_style(background, edge, padding))
    parent.add_child(panel)
    return panel

func _column(parent: Control, spacing: int) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", spacing)
    parent.add_child(column)
    return column

func _row(parent: Control, spacing: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", spacing)
    parent.add_child(row)
    return row

func _label(parent: Control, text: String, points: int, color: Color, font: Font = null) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label

func _photo(texture: Texture2D, height: int) -> TextureRect:
    var photo := TextureRect.new()
    photo.texture = texture
    photo.custom_minimum_size.y = height
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return photo

func _action(parent: Control, text: String, primary: bool, callback: Callable) -> Button:
    var button := UI.action_button(text, bold_font, primary)
    button.pressed.connect(func():
        if not is_queued_for_deletion() and button.is_visible_in_tree():
            callback.call()
    )
    parent.add_child(button)
    return button
