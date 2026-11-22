extends VBoxContainer

signal opponent_chosen(opponent: Dictionary)
signal tutorial_skipped()

const UI := preload("res://scripts/ui/reference_ui.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const INK := Color("#0a1420")
const NAVY := Color("#101e2c")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#bec9d3")

var offers: Array[Dictionary] = []
var show_first_bout_guide := false
var _analyzed: Dictionary = {}
var recommended_opponent_id := ""
var heading_font: Font
var bold_font: Font
var _open_details: Control
var _open_button: Button

func _ready() -> void:
    name = "ReferenceFightOffers"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 8)
    _hero()
    for entry in offers:
        _card(entry)
    if offers.is_empty():
        var notice := _panel(self, NAVY, UI.GOLD_DARK, 9)
        _label(notice, "현재 선택할 수 있는 경기 제안이 없습니다.", 13, PAPER, true)

func _hero() -> void:
    var banner := _panel(self, INK, UI.GOLD_DARK, 3)
    var backdrop := Control.new()
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.clip_contents = true
    banner.add_child(backdrop)
    for right in [false, true]:
        var light := _texture(LIGHTS)
        light.anchor_left = 0.67 if right else 0.0
        light.anchor_right = 1.0 if right else 0.33
        light.anchor_bottom = 1.0
        light.flip_h = right
        backdrop.add_child(light)

    var content := _column(banner, 3)
    var heading := _label(content, "FIGHT OFFERS", 38, PAPER)
    heading.name = "FightOffersTitle"
    heading.add_theme_font_override("font", UI.DISPLAY_FONT)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var plaque := _panel(content, UI.GOLD, UI.GOLD_BRIGHT, 2)
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var title := _label(plaque, "경기 제안", 19, INK)
    title.custom_minimum_size.x = 146
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_override("font", heading_font)

    var intro_text := "5/10 · 상대의 분석을 열어 강점·약점·버릇을 확인한 다음 계약하세요. 튜토리얼 경기도 공식 전적에 기록됩니다." if show_first_bout_guide else "상대의 스타일·난이도·보상을 비교하세요."
    var intro := _label(content, intro_text, 12, PAPER, true)
    intro.name = "FightOffersIntro"
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if show_first_bout_guide:
        var skip := Button.new()
        skip.name = "TutorialSkip"
        skip.text = "튜토리얼 건너뛰기"
        skip.flat = true
        skip.custom_minimum_size.y = 34
        skip.pressed.connect(func(): tutorial_skipped.emit())
        content.add_child(skip)

func _card(entry: Dictionary) -> void:
    var opponent: Dictionary = entry["opponent"]
    var id := str(opponent["id"])
    var scouting: Dictionary = opponent.get("scouting", {})
    var is_title := bool(opponent.get("title_fight", false))
    var recommended := id == recommended_opponent_id
    var card := _panel(self, NAVY, UI.GOLD_BRIGHT if is_title or recommended else UI.GOLD_DARK, 5)
    card.name = "OpponentCard_" + id
    var content := _column(card, 5)
    var row := _row(content, 8)

    var portrait_frame := _panel(row, INK, Color("#263746"), 1)
    portrait_frame.size_flags_horizontal = Control.SIZE_FILL
    portrait_frame.custom_minimum_size.x = 111
    var portrait := _texture(entry["portrait"])
    portrait.name = "FightOfferPortrait_" + id
    portrait.clip_contents = true
    portrait_frame.add_child(portrait)

    var info := _column(row, 2)
    var title_row := _row(info, 5)
    var title := _label(title_row, str(opponent["name"]), 18, PAPER, true)
    title.add_theme_font_override("font", heading_font)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var rank := _panel(title_row, INK, UI.GOLD_DARK, 3)
    rank.size_flags_horizontal = Control.SIZE_FILL
    rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var rank_label := _label(rank, "랭킹 #%d" % int(opponent["rank"]), 11, UI.GOLD_BRIGHT)
    rank_label.name = "FightOfferRank_" + id
    rank_label.add_theme_font_override("font", bold_font)

    var details_row := _row(info, 6)
    var identity := _label(details_row, "%s  [%s]" % [entry["style"], entry["country"]], 11, UI.GOLD_BRIGHT, true)
    identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var difficulty := str(UI.DIFFICULTY.get(opponent.get("difficulty", ""), "미정"))
    var difficulty_text := "난이도 %s" % difficulty
    if recommended:
        difficulty_text = "첫 경기 추천 · " + difficulty_text
    var difficulty_label := _label(details_row, difficulty_text, 11, UI.GOLD_BRIGHT if recommended else MUTED)
    if recommended:
        difficulty_label.name = "FirstBoutOpponentRecommendation"
    if is_title:
        var match_title := _label(info, str(opponent.get("title_label", "타이틀전")), 11, UI.GOLD_BRIGHT, true)
        match_title.add_theme_font_override("font", bold_font)

    var brief := _label(info, str(scouting.get("strength", "상대 정보가 없습니다.")), 11, PAPER, true)
    brief.max_lines_visible = 2
    brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

    var rewards := _row(_panel(info, INK, Color("#5c4b35"), 4), 4)
    rewards.name = "FightOfferRewards_" + id
    _reward(rewards, "파이트머니", "%s원" % entry["purse"])
    _reward(rewards, "승리 평판", "%+d" % int(opponent.get("reputation_reward", 0)))
    _reward(rewards, "승패 포인트", "%+d / %d" % [int(opponent.get("career_points_win", 0)), -absi(int(opponent.get("career_points_loss", 0)))])

    var buttons := _row(info, 6)
    var inspect := UI.action_button("분석", bold_font)
    inspect.name = "FightOfferAnalyze_" + id
    buttons.add_child(inspect)
    var accept := UI.action_button("선택  ›", bold_font, true)
    accept.name = "FightOfferSelect_" + id
    if show_first_bout_guide:
        accept.disabled = true
        accept.text = "분석 후 선택"
    accept.pressed.connect(func():
        if not is_queued_for_deletion() and (not show_first_bout_guide or bool(_analyzed.get(id, false))):
            opponent_chosen.emit(opponent)
    )
    buttons.add_child(accept)

    var details := _analysis(content, opponent, scouting)
    details.hide()
    inspect.pressed.connect(func():
        _toggle_analysis(details, inspect)
        if show_first_bout_guide:
            _analyzed[id] = true
            accept.disabled = false
            accept.text = "5/10 · 상대 선택  ›"
    )

func _analysis(parent: VBoxContainer, opponent: Dictionary, scouting: Dictionary) -> PanelContainer:
    var panel := _panel(parent, INK, UI.GOLD_DARK, 7)
    panel.name = "FightOfferAnalysis_" + str(opponent["id"])
    var body := _column(panel, 4)
    _label(body, "상대 분석 · %s" % str(opponent["name"]), 14, UI.GOLD_BRIGHT).add_theme_font_override("font", bold_font)
    if show_first_bout_guide:
        _label(body, "6/10 · 강점은 상대의 위험한 부분, 약점은 공략할 틈, 버릇은 공격을 예측할 단서입니다. 이 세 가지를 보고 전술을 결정하세요.", 12, UI.GOLD_BRIGHT, true)
    for item in [["strength", "강점"], ["weakness", "약점"], ["tell", "주의할 패턴"]]:
        var text := str(scouting.get(item[0], ""))
        if not text.is_empty():
            _label(body, "%s · %s" % [item[1], text], 12, PAPER, true)
    var stats: Dictionary = opponent.get("stats", {})
    _label(body, "파워 %d · 스피드 %d · 기술 %d · 수비 %d · 지구력 %d" % [
        int(stats.get("power", 0)), int(stats.get("speed", 0)), int(stats.get("technique", 0)),
        int(stats.get("defense", 0)), int(stats.get("conditioning", 0)),
    ], 11, MUTED, true)
    return panel

func _toggle_analysis(details: Control, button: Button) -> void:
    var should_open := not details.visible
    if is_instance_valid(_open_details):
        _open_details.hide()
        _open_button.text = "분석"
        _open_details = null
        _open_button = null
    if should_open:
        details.show()
        button.text = "분석 닫기"
        _open_details = details
        _open_button = button
        await get_tree().process_frame
        if is_instance_valid(details) and details.is_visible_in_tree():
            var scroll := find_parent("V17ContentScroll") as ScrollContainer
            if scroll != null:
                scroll.ensure_control_visible(details)

func _reward(row: HBoxContainer, caption: String, value: String) -> void:
    var slot := _column(row, 1)
    var title := _label(slot, caption, 9, MUTED)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var amount := _label(slot, value, 13, UI.GOLD_BRIGHT)
    amount.add_theme_font_override("font", bold_font)
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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

func _label(parent: Control, text: String, points: int, color: Color, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", color)
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label

func _panel(parent: Container, background: Color, edge: Color, padding: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.panel_style(background, edge, padding))
    parent.add_child(panel)
    return panel

func _texture(texture: Texture2D) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = texture
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect
