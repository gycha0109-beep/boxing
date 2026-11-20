extends VBoxContainer

signal continue_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const HERO_PLAYER := preload("res://assets/visual/reference_v1/profile_boxer.png")
const HERO_HAN := preload("res://assets/visual/reference_v1/scouting_han.png")
const INK := Color("#0a141f")
const NAVY := Color("#111e2c")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#c1cbd4")
const RED := Color("#ef8073")
const BLUE := Color("#71baf9")
const GREEN := Color("#8bdfa0")

var summary: Dictionary
var boxer: Dictionary
var career: Dictionary
var result_id: String
var result_text: String
var opponent_name: String
var opponent_portrait: Texture2D
var weight_class: String
var plan_name: String
var injury_text: String
var money_text: Callable
var heading_font: Font
var bold_font: Font

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 7)
    _hero()
    _settlement()
    _career_update()
    if not injury_text.is_empty():
        var injury := _row(_frame(self, INK, UI.GOLD_DARK, 6), 9)
        _label(injury, "경기 후 부상", 11, RED, bold_font)
        _label(injury, injury_text, 11, PAPER, null, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var next := UI.action_button("커리어 계속", heading_font, true)
    next.name = "FightResultContinue"
    next.custom_minimum_size = Vector2(316, 68)
    next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    next.add_theme_font_size_override("font_size", 20)
    next.pressed.connect(func():
        if not next.disabled and not is_queued_for_deletion():
            next.disabled = true
            continue_requested.emit()
    )
    add_child(next)

func _hero() -> void:
    var frame := _frame(self, INK, UI.GOLD_BRIGHT, 5)
    var layer := Control.new()
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.clip_contents = true
    frame.add_child(layer)
    for right in [false, true]:
        var lights := _image(layer, LIGHTS, 0.70 if right else 0.0, 1.0 if right else 0.30, 3, false)
        lights.anchor_bottom = 0.44
        lights.flip_h = right
        lights.modulate.a = 0.70
    var hero_crop := AtlasTexture.new()
    hero_crop.atlas = HERO_PLAYER
    hero_crop.region = Rect2(0, 0, 361, 425)
    hero_crop.filter_clip = true
    _image(layer, hero_crop, 0.0, 0.42, 72, true).modulate.a = 0.86
    var rival := HERO_HAN if str(summary.get("opponent_id", "")) == "han_do-yun" else opponent_portrait
    _image(layer, rival, 0.58, 1.0, 80, true).modulate.a = 0.85

    var content := _column(frame, 3)
    var title := _label(content, "RESULT", 32, PAPER, heading_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var plaque := _frame(content, Color("#d7a456"), UI.GOLD_BRIGHT, 1)
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var sub := _label(plaque, "FIGHT NIGHT", 15, INK, heading_font)
    sub.custom_minimum_size.x = 143
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var division := _label(content, "경기 결과  ·  " + weight_class, 10, MUTED, bold_font)
    division.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var outcome := _column(content, 0)
    outcome.custom_minimum_size.y = 111
    outcome.alignment = BoxContainer.ALIGNMENT_CENTER
    var color := UI.GOLD_BRIGHT
    if result_id.begins_with("LOSS"):
        color = RED
    elif result_id == "DRAW":
        color = PAPER
    var verdict := _label(outcome, result_text, 43, color, heading_font)
    verdict.name = "FightResultVerdict"
    verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    verdict.add_theme_color_override("font_outline_color", INK)
    verdict.add_theme_constant_override("outline_size", 9)
    if int(summary.get("ending_round", 0)) > 0:
        var round_label := _label(outcome, "ROUND %d 종료" % int(summary["ending_round"]), 12, PAPER, bold_font)
        round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        round_label.add_theme_color_override("font_outline_color", INK)
        round_label.add_theme_constant_override("outline_size", 5)

    var match_row := _row(content, 5)
    _nameplate(match_row, str(boxer.get("name", "무명 복서")), _side_outcome(true), RED)
    var vs := _label(match_row, "VS", 20, UI.GOLD_BRIGHT, heading_font)
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _nameplate(match_row, opponent_name, _side_outcome(false), BLUE)

func _side_outcome(is_player: bool) -> String:
    if result_id.begins_with("WIN"):
        return "승리" if is_player else "패배"
    if result_id.begins_with("LOSS"):
        return "패배" if is_player else "승리"
    if result_id == "DRAW":
        return "무승부"
    return "내 선수" if is_player else "상대"

func _nameplate(parent: HBoxContainer, fighter_name: String, status: String, edge: Color) -> void:
    var content := _column(_frame(parent, INK, edge, 5), 1)
    _label(content, status, 10, UI.GOLD_BRIGHT if status == "승리" else MUTED, bold_font)
    var title := _label(content, fighter_name, 14, PAPER, heading_font)
    title.clip_text = true
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _image(parent: Control, texture: Texture2D, start: float, end: float, top: float, cover: bool) -> TextureRect:
    var art := TextureRect.new()
    art.texture = texture
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_SCALE
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(art)
    art.anchor_left = start
    art.anchor_right = end
    art.anchor_bottom = 1.0
    art.offset_top = top
    return art

func _settlement() -> void:
    var table := _column(_frame(self, NAVY, UI.GOLD_DARK, 6), 2)
    _stat_row(table, "게임플랜", plan_name)
    if summary.has("purse"):
        _stat_row(table, "파이트머니", "%s원" % money_text.call(int(summary["purse"])), UI.GOLD_BRIGHT)
    if summary.has("cycle_cost") and summary.has("purse"):
        var cost := int(summary["cycle_cost"])
        _stat_row(table, "캠프 비용", "%s원  ·  잔액 변동 %s원" % [
            _signed_money(-cost), _signed_money(int(summary["purse"]) - cost),
        ], MUTED)
    var cards: Array = summary.get("round_cards", [])
    var scores: Array[String] = []
    var player_total := 0
    var opponent_total := 0
    for index in range(cards.size()):
        var card: Variant = cards[index]
        if card is Array and card.size() >= 2:
            player_total += int(card[0])
            opponent_total += int(card[1])
            scores.append("R%d %d:%d" % [index + 1, int(card[0]), int(card[1])])
    if not scores.is_empty():
        _stat_row(table, "라운드 점수", "합계 %d:%d  ·  %s" % [player_total, opponent_total, "  ·  ".join(scores)])
    var previous: Dictionary = summary.get("previous", {})
    var points := int(career.get("career_points", 0))
    var points_line := "%d pt" % points
    if previous.has("career_points"):
        points_line += "  (%+d)" % (points - int(previous["career_points"]))
    _stat_row(table, "커리어 포인트", points_line, UI.GOLD_BRIGHT)

    var rank := int(career.get("rank", 0))
    var ranking := "#%d" % rank
    if previous.has("rank"):
        var old_rank := int(previous["rank"])
        var movement := old_rank - rank
        ranking = "#%d  →  #%d" % [old_rank, rank]
        if movement != 0:
            ranking += "  (%d계단 %s)" % [absi(movement), "상승" if movement > 0 else "하락"]
    _stat_row(table, "랭킹", ranking, UI.GOLD_BRIGHT)

func _signed_money(value: int) -> String:
    return ("+" if value > 0 else "") + str(money_text.call(value))

func _stat_row(parent: VBoxContainer, caption: String, value: String, tint: Color = PAPER) -> void:
    var row := _row(parent, 8)
    row.custom_minimum_size.y = 24
    var label := _label(row, caption, 11, UI.GOLD_BRIGHT, bold_font)
    label.custom_minimum_size.x = 95
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var data := _label(row, value, 12, tint, bold_font, true)
    data.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    data.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _career_update() -> void:
    var previous: Dictionary = summary.get("previous", {})
    var row := _row(self, 7)
    var conditions := _column(_frame(row, NAVY, UI.GOLD_DARK, 6), 3)
    _label(conditions, "컨디션 변화", 13, UI.GOLD_BRIGHT, bold_font)
    _condition(conditions, "health", "건강", RED, previous)
    _condition(conditions, "fatigue", "피로", BLUE, previous)
    _label(conditions, "체중 %.2fkg" % float(boxer.get("weight_kg", 0.0)), 10, MUTED)

    var record := _column(_frame(row, NAVY, UI.GOLD_DARK, 6), 2)
    _label(record, "전적 업데이트", 13, UI.GOLD_BRIGHT, bold_font)
    var score := _label(record, "%d승 %d패 %d무" % [int(career["wins"]), int(career["losses"]), int(career["draws"])], 21, PAPER, heading_font, true)
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var bouts := _label(record, "%d경기" % int(career["fights"]), 10, MUTED)
    bouts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _condition(parent: VBoxContainer, key: String, caption: String, tint: Color, previous: Dictionary) -> void:
    var row := _row(parent, 4)
    _label(row, caption, 10, tint, bold_font)
    var amount := int(boxer.get(key, 0))
    var text := "%d%%" % amount
    if previous.has(key):
        text = "%d%% → %d%% (%+d)" % [int(previous[key]), amount, amount - int(previous[key])]
    var value := _label(row, text, 10, PAPER, bold_font, true)
    value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _frame(parent: Container, background: Color, edge: Color, padding: int) -> PanelContainer:
    var frame := PanelContainer.new()
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    frame.add_theme_stylebox_override("panel", UI.beveled_panel_style(background, edge, padding))
    parent.add_child(frame)
    return frame

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

func _label(parent: Control, text: String, size: int, color: Color, font: Font = null, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label
