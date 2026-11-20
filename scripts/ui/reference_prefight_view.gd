extends VBoxContainer

signal plan_chosen(id: String)
signal back_requested()
signal opponent_back_requested()
signal fight_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
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
var tendency: String
var comparison: Array[Dictionary] = []
var plans: Array[Dictionary] = []
var weigh: Dictionary
var weight_class: Dictionary
var confirmed_plan: Dictionary
var allow_plan_back := false
var heading_font: Font
var bold_font: Font

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    if weighing:
        _weigh_in()
    else:
        _scouting()

func _scouting() -> void:
    var hero := _banner("OPPONENT SCOUTING", "상대 분석")
    var row := _row(hero, 8)
    var portrait := _photo(opponent_photo, 143)
    portrait.custom_minimum_size.x = 136
    row.add_child(portrait)
    var info := _column(row, 3)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _label(info, "다음 상대", 10, UI.GOLD_BRIGHT, bold_font)
    _label(info, str(opponent["name"]), 22, PAPER, heading_font)
    _label(info, opponent_details, 11, MUTED)
    var opponent_title := str(opponent.get("title_label", ""))
    if not opponent_title.is_empty():
        _label(info, opponent_title, 11, UI.GOLD_BRIGHT, bold_font)
    _label(info, tendency, 11, PAPER, bold_font)

    var report := _column(_panel(self, NAVY, UI.GOLD_DARK, 7), 3)
    for fact in [["강점", "strength", RED], ["약점", "weakness", BLUE], ["주의할 패턴", "tell", UI.GOLD]]:
        var line := _row(report, 8)
        var caption := _label(line, fact[0], 11, fact[2], bold_font)
        caption.custom_minimum_size.x = 66
        var detail := _label(line, str(analysis.get(fact[1], "정보 없음")), 11, PAPER)
        detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var recommended: Array[String] = []
    for plan in plans:
        if bool(plan["recommended"]):
            recommended.append(str(plan["name"]))
    if not recommended.is_empty():
        _label(report, "추천 게임플랜 · " + " / ".join(recommended), 11, UI.GOLD_BRIGHT, bold_font)

    _comparison()
    var nav := _row(self, 7)
    _action(nav, "← 컨디션 다시 선택", false, func(): back_requested.emit())
    var view_plans := _action(nav, "게임플랜 보기  ›", true, _jump_to_plans)
    view_plans.name = "ScoutingShowPlans"
    _game_plans()

func _comparison() -> void:
    var box := _column(_panel(self, INK, UI.GOLD_DARK, 7), 2)
    var title := _label(box, "주요 능력치 비교", 14, UI.GOLD_BRIGHT, bold_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var names := _row(box, 6)
    var left := _label(names, "내 선수 · " + str(player.get("name", "")), 11, RED, bold_font)
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var right := _label(names, str(opponent["name"]), 11, BLUE, bold_font)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    for stat in comparison:
        var line := _row(box, 6)
        var label := _label(line, str(stat["name"]), 11, UI.GOLD_BRIGHT, bold_font)
        label.custom_minimum_size.x = 54
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var before := _meter(line, int(stat["player"]), RED, true)
        line.move_child(before, 0)
        _meter(line, int(stat["opponent"]), BLUE, false)
    _label(box, "체중 %.2fkg  ·  피로 %d%%  ·  건강 %d%%" % [
        float(player["weight_kg"]), int(player["fatigue"]), int(player["health"]),
    ], 11, MUTED)

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

func _game_plans() -> void:
    var heading := _label(self, "게임플랜 선택", 23, PAPER, heading_font)
    heading.name = "GamePlanHeading"
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    add_child(grid)
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
    _action(self, "← 상대 다시 선택", false, func(): opponent_back_requested.emit())

func _jump_to_plans() -> void:
    var scroll := find_parent("V17ContentScroll") as ScrollContainer
    var target := get_node_or_null("GamePlanHeading") as Control
    if scroll != null and target != null:
        scroll.scroll_vertical += roundi(target.get_global_rect().position.y - scroll.get_global_rect().position.y)

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
        lamps.offset_bottom = 106.0
    var body := _column(panel, 3)
    var heading := _label(body, title, 27, PAPER, heading_font)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var plaque := _panel(body, UI.GOLD, UI.GOLD_BRIGHT, 1)
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var caption := _label(plaque, subtitle, 14, INK, bold_font)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.custom_minimum_size.x = 160
    return body

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
        if not is_queued_for_deletion():
            callback.call()
    )
    parent.add_child(button)
    return button
