extends VBoxContainer

signal plan_confirmed(plan_id: String)
signal offers_requested()
signal condition_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const INK := Color("#07131f")
const PANEL := Color("#101e2b")
const PANEL_ALT := Color("#172737")
const GOLD := Color("#e8bd70")
const GOLD_BRIGHT := Color("#ffe1a0")
const EDGE := Color("#80623b")
const PAPER := Color("#f5f0e6")
const MUTED := Color("#bdc7d1")
const GREEN := Color("#83d1a0")
const RED := Color("#e98980")
const BLUE := Color("#7cbbe8")
const PLAN_ART_SPARRING := preload("res://assets/visual/reference_v1/training_sparring.png")
const PLAN_ART_RUNNING := preload("res://assets/visual/reference_v1/training_running.png")
const PLAN_ART_BAG := preload("res://assets/visual/reference_v1/training_bag.png")

var player: Dictionary = {}
var career: Dictionary = {}
var opponent: Dictionary = {}
var plans: Array = []
var suggested_plans: Array = []
var plan_effects: Dictionary = {}
var player_texture: Texture2D
var opponent_texture: Texture2D
var heading_font: Font
var bold_font: Font
var money_text: Callable
var selected_plan_id := ""
var plan_panels: Dictionary = {}
var plan_buttons: Dictionary = {}

func _ready() -> void:
    name = "ReferenceMatchup"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 8)
    _initialize_selected_plan()
    _heading()
    _matchup()
    _fight_information()
    _reward_panel()
    _opponent_analysis()
    _strategy_choices()
    _footer()

func _initialize_selected_plan() -> void:
    if not selected_plan_id.is_empty():
        return
    if not suggested_plans.is_empty():
        selected_plan_id = str(suggested_plans[0])
    elif not plans.is_empty():
        selected_plan_id = str(plans[0].get("id", ""))

func _heading() -> void:
    var title := _label(self, "경기 준비 / 매치업", 22, PAPER, heading_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var subtitle := _label(self, "F I G H T   P R E P   /   M A T C H U P", 9, GOLD, bold_font)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var line := ColorRect.new()
    line.color = EDGE
    line.custom_minimum_size.y = 1
    add_child(line)

func _matchup() -> void:
    var outer := Control.new()
    outer.custom_minimum_size.y = 206
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(outer)
    var frame := _panel(outer, INK, GOLD, 3)
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 2)
    frame.add_child(content)
    var title_fight := bool(opponent.get("title_fight", false))
    var badge := _label(content, str(opponent.get("title_label", "정규 랭킹전")) if title_fight else "OFFICIAL BOUT", 10, GOLD_BRIGHT, bold_font)
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 3)
    content.add_child(row)
    _fighter_side(row, player, player_texture, true)
    var versus := VBoxContainer.new()
    versus.custom_minimum_size.x = 40
    versus.alignment = BoxContainer.ALIGNMENT_CENTER
    versus.add_theme_constant_override("separation", 2)
    row.add_child(versus)
    _label(versus, "VS", 23, GOLD_BRIGHT, heading_font).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label(versus, "◆", 11, GOLD, bold_font).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _fighter_side(row, opponent, opponent_texture, false)

func _fighter_side(parent: HBoxContainer, data: Dictionary, texture: Texture2D, is_player: bool) -> void:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 3)
    parent.add_child(box)
    var photo := TextureRect.new()
    photo.texture = texture
    photo.custom_minimum_size = Vector2(0, 106)
    photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(photo)
    _label(box, "내 복서" if is_player else "도전자", 9, GOLD, bold_font)
    var name := _label(box, str(data.get("name", "복서")), 15, PAPER, heading_font)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label(box, "랭킹 #%d" % int(data.get("rank", 0)), 10, MUTED)
    var stats: Dictionary = data.get("stats", {})
    var overall := _overall(stats if not stats.is_empty() else data)
    _label(box, "OVR %d" % overall, 13, GOLD_BRIGHT, bold_font)
    if is_player:
        _label(box, "%d승 %d패 %d무" % [int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0))], 9, MUTED)
    else:
        _label(box, _style_name(str(data.get("style", ""))), 9, MUTED)

func _fight_information() -> void:
    var outer := _panel(self, PANEL, EDGE, 8)
    var content := _column(outer, 3)
    var title_fight := bool(opponent.get("title_fight", false))
    _eyebrow(content, "경기 정보")
    _label(content, str(opponent.get("title_label", "정규 랭킹전")) if title_fight else "다음 커리어 매치", 18, PAPER, heading_font)
    var weight: Dictionary = GameState.career_balance.get("weight_class", {})
    _label(content, "%s · 시즌 %d · %d번째 경기" % [
        str(weight.get("name", "체급 미정")),
        1 + int(career.get("fights", 0)) / 4,
        int(career.get("fights", 0)) + 1
    ], 11, MUTED, bold_font)

func _reward_panel() -> void:
    var purse := int(opponent.get("purse", 0))
    var reputation := int(opponent.get("reputation_reward", 0))
    var points := int(opponent.get("career_points_win", 0))
    var panel := _panel(self, PANEL_ALT, EDGE, 8)
    var content := _column(panel, 4)
    _eyebrow(content, "보상 및 파이트머니")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    content.add_child(row)
    _reward_metric(row, "파이트머니", _money(purse), 15)
    _reward_metric(row, "인기 보상", "+%d" % reputation, 13)
    _reward_metric(row, "커리어 포인트", "%d pt" % points, 13)

func _reward_metric(parent: HBoxContainer, title: String, value: String, size: int) -> void:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 2)
    parent.add_child(box)
    _label(box, title, 9, GOLD, bold_font)
    _label(box, value, size, PAPER, heading_font)

func _opponent_analysis() -> void:
    var scouting: Dictionary = opponent.get("scouting", {})
    var stats: Dictionary = opponent.get("stats", {})
    var panel := _panel(self, PANEL, EDGE, 8)
    var content := _column(panel, 4)
    _eyebrow(content, "상대 프로필 · 스타일 분석")
    var profile := HBoxContainer.new()
    profile.add_theme_constant_override("separation", 8)
    content.add_child(profile)
    var portrait := TextureRect.new()
    portrait.texture = opponent_texture
    portrait.custom_minimum_size = Vector2(104, 108)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    profile.add_child(portrait)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_theme_constant_override("separation", 3)
    profile.add_child(copy)
    _label(copy, str(opponent.get("name", "상대 선수")), 19, PAPER, heading_font)
    _label(copy, "랭킹 #%d · %s" % [int(opponent.get("rank", 0)), _style_name(str(opponent.get("style", "")))], 11, GOLD, bold_font)
    var strength := _label(copy, "강점 · %s" % str(scouting.get("strength", "분석 정보 없음")), 10, MUTED)
    strength.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var weakness := _label(copy, "약점 · %s" % str(scouting.get("weakness", "분석 정보 없음")), 10, MUTED)
    weakness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _rule(content)
    _label(content, "주요 능력치", 12, GOLD_BRIGHT, bold_font)
    var player_stats: Dictionary = player
    for item in [
        {"id":"power","label":"공격력"},
        {"id":"speed","label":"속도"},
        {"id":"technique","label":"기술"},
        {"id":"defense","label":"수비력"},
        {"id":"conditioning","label":"체력"},
    ]:
        _compare_bar(content, str(item.label), int(player_stats.get(str(item.id), 0)), int(stats.get(str(item.id), 0)))
    var tell := _label(content, "전투 패턴 · %s" % str(scouting.get("tell", "추가 분석 정보 없음")), 10, MUTED)
    tell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _compare_bar(parent: Control, title: String, mine: int, theirs: int) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    parent.add_child(row)
    var left := _label(row, str(mine), 10, PAPER, bold_font)
    left.custom_minimum_size.x = 22
    var player_bar := _bar(mine, BLUE)
    player_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(player_bar)
    var name := _label(row, title, 10, MUTED, bold_font)
    name.custom_minimum_size.x = 42
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var opponent_bar := _bar(theirs, GOLD)
    opponent_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(opponent_bar)
    var right := _label(row, str(theirs), 10, PAPER, bold_font)
    right.custom_minimum_size.x = 22
    right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _bar(value: int, tint: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.min_value = 0
    bar.max_value = 100
    bar.value = clampi(value, 0, 100)
    bar.show_percentage = false
    bar.custom_minimum_size.y = 7
    bar.add_theme_stylebox_override("background", UI.panel_style(Color("#273543"), Color("#273543"), 0))
    bar.add_theme_stylebox_override("fill", UI.panel_style(tint, tint, 0))
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return bar

func _strategy_choices() -> void:
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 5)
    add_child(header)
    var title := _label(header, "경기 전략 선택", 16, GOLD_BRIGHT, heading_font)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(header, "상대 스타일에 맞춰 선택", 10, MUTED, bold_font)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    add_child(grid)
    plan_panels.clear()
    plan_buttons.clear()
    for plan_value in plans:
        var plan: Dictionary = plan_value
        var plan_id := str(plan.get("id", ""))
        var selected := plan_id == selected_plan_id
        var card := _panel(grid, PANEL_ALT if selected else PANEL, GOLD if selected else EDGE, 6)
        card.name = "MatchPlan_" + plan_id
        plan_panels[plan_id] = card
        var content := _column(card, 4)
        var art := TextureRect.new()
        art.name = "MatchPlanArt_" + plan_id
        art.texture = _plan_art(plan_id)
        art.custom_minimum_size.y = 64
        art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(art)
        _label(content, str(plan.get("name", "전략")), 17, PAPER, heading_font)
        var risk := str(plan.get("risk", "중간"))
        _label(content, "리스크 · %s%s" % [risk, "  ✓ 선택됨" if selected else ""], 10, GOLD if selected else MUTED, bold_font)
        var description := _label(content, str(plan.get("description", "")), 10, MUTED)
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var effects := _label(content, str(plan_effects.get(plan_id, "")), 10, GREEN)
        effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var choose := UI.action_button("선택됨" if selected else "전략 선택", bold_font, selected)
        choose.name = "MatchPlanSelect_" + plan_id
        choose.custom_minimum_size.y = 38
        choose.pressed.connect(Callable(self, "_select_plan").bind(plan_id))
        content.add_child(choose)
        plan_buttons[plan_id] = choose

func _plan_art(plan_id: String) -> Texture2D:
    match plan_id:
        "outside_boxing":
            return PLAN_ART_RUNNING
        "pressure", "body_attack":
            return PLAN_ART_BAG
        _:
            return PLAN_ART_SPARRING

func _select_plan(plan_id: String) -> void:
    if not plan_panels.has(plan_id):
        return
    selected_plan_id = plan_id
    for key in plan_panels.keys():
        var card: PanelContainer = plan_panels[key]
        var selected := str(key) == selected_plan_id
        card.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL_ALT if selected else PANEL, GOLD if selected else EDGE, 6))
        var button: Button = plan_buttons[key]
        button.text = "선택됨" if selected else "전략 선택"
        button.add_theme_stylebox_override("normal", UI.gold_button_style() if selected else UI.panel_style(PANEL_ALT, EDGE, 4))

func _footer() -> void:
    var confirm := UI.action_button("선택한 전략으로 계체 진행  ›", heading_font, true)
    confirm.name = "MatchupConfirmPlan"
    confirm.custom_minimum_size.y = 60
    confirm.add_theme_font_size_override("font_size", 18)
    confirm.pressed.connect(func():
        if not selected_plan_id.is_empty():
            plan_confirmed.emit(selected_plan_id)
    )
    add_child(confirm)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 7)
    add_child(row)
    var back_condition := UI.action_button("← 컨디션", bold_font, false)
    back_condition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back_condition.pressed.connect(func(): condition_requested.emit())
    row.add_child(back_condition)
    var back_offers := UI.action_button("← 상대 다시 선택", bold_font, false)
    back_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back_offers.pressed.connect(func(): offers_requested.emit())
    row.add_child(back_offers)

func _column(parent: Control, gap: int = 4) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", gap)
    parent.add_child(column)
    return column

func _panel(parent: Control, background: Color, edge: Color, padding: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(background, edge, padding))
    parent.add_child(panel)
    return panel

func _label(parent: Control, text_value: String, points: int, tint: Color = PAPER, font: Font = null) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", tint)
    if font != null:
        label.add_theme_font_override("font", font)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label

func _eyebrow(parent: Control, text_value: String) -> void:
    _label(parent, text_value, 10, GOLD, bold_font)

func _rule(parent: Control) -> void:
    var line := ColorRect.new()
    line.color = EDGE
    line.custom_minimum_size.y = 1
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(line)

func _overall(stats: Dictionary) -> int:
    var total := 0
    for key in ["power", "speed", "technique", "defense", "conditioning"]:
        total += int(stats.get(key, 0))
    return roundi(float(total) / 5.0)

func _style_name(style: String) -> String:
    match style:
        "swarmer": return "압박형"
        "out_boxer": return "아웃복서"
        "counter": return "카운터형"
        "slugger": return "강타형"
        _: return "복싱 스타일"

func _money(value: int) -> String:
    if money_text.is_valid():
        return str(money_text.call(value)) + "원"
    return "%d원" % value
