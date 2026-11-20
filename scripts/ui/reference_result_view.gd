extends VBoxContainer

signal continue_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const PORTRAIT_SHADER := preload("res://scripts/ui/reference_result_portrait.gdshader")
const ARENA := preload("res://assets/visual/v0.7/arena/arena_title_night.png")
const HERO_PLAYER := preload("res://assets/visual/reference_v1/profile_boxer.png")
const HERO_HAN := preload("res://assets/visual/reference_v1/scouting_han.png")
const INK := Color("#080d13")
const STEEL := Color("#11171e")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#b9c1cc")
const RED := Color("#eb8b80")
const BLUE := Color("#84bdeb")
const GREEN := Color("#a0df95")

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
    add_theme_constant_override("separation", 6)
    _hero()
    _settlement()
    _career_update()
    _match_commentary()
    if not injury_text.is_empty():
        var injury := _row(_frame(self, INK, UI.GOLD_DARK, 6), 9)
        Art.result_icon(injury, &"injury")
        _label(injury, "경기 후 부상", 11, RED, bold_font)
        _label(injury, injury_text, 11, PAPER, null, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _continue_button()

func _hero() -> void:
    var player_status := _side_outcome(true)
    var opponent_status := _side_outcome(false)
    var frame := _frame(self, INK, UI.GOLD_DARK, 2)
    var layer := Control.new()
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.clip_contents = true
    frame.add_child(layer)

    var arena := AtlasTexture.new()
    arena.atlas = ARENA
    arena.region = Rect2(0, 110, 1080, 1250)
    arena.filter_clip = true
    _image(layer, arena, 0.0, 1.0, 0, false).modulate = Color("#9fa7b7")

    var player := AtlasTexture.new()
    player.atlas = HERO_PLAYER
    player.region = Rect2(0, 0, 361, 453)
    player.filter_clip = true
    var is_han := str(summary.get("opponent_id", "")) == "han_do-yun"
    var rival := HERO_HAN if is_han else opponent_portrait
    var player_won := player_status == "승리"
    var rival_won := opponent_status == "승리"
    _portrait(layer, player, -0.05, 0.485, 59 if not rival_won else 93, false, true, player_status)
    if rival != null:
        _portrait(layer, rival, 0.55, 1.03, 63 if rival_won else 109, true, is_han, opponent_status)
    if player_won or rival_won:
        Art.sparks(layer, 0.0 if player_won else 1.0)
        Art.glow(layer, Vector2(0.15 if player_won else 0.85, 0.43), Vector2(214, 218), Color(1, 0.67, 0.32, 0.19))
    Art.glow(layer, Vector2(0.5, 0.43), Vector2(249, 113), Color(0.04, 0.04, 0.05, 0.75))
    var light_color := Color(1, 0.55, 0.16, 0.90) if player_won or rival_won else Color(0.64, 0.75, 0.93, 0.60)
    Art.glow(layer, Vector2(0.5, 0.391), Vector2(206, 46), light_color)
    Art.glow(layer, Vector2(0.5, 0.391), Vector2(265, 6), light_color)
    Art.glow(layer, Vector2(0.5, 0.391), Vector2(46, 21), Color(1.0, 0.85, 0.59, 0.78))

    var content := _column(frame, 2)
    var masthead := _row(content, 7)
    masthead.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(masthead, 30, UI.GOLD, false)
    var title := _label(masthead, "RESULT", 46, PAPER, UI.DISPLAY_FONT)
    _outline(title, 6)
    Art.laurel(masthead, 30, UI.GOLD, true)

    var plaque := PanelContainer.new()
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    plaque.add_theme_stylebox_override("panel", Art.gold_plate(148, 23, Color("#c48735"), 2))
    content.add_child(plaque)
    var sub := _label(plaque, "FIGHT NIGHT", 17, INK, UI.DISPLAY_FONT)
    sub.custom_minimum_size.x = 145
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var division := _label(content, weight_class + "  ·  경기 결과", 10, PAPER, bold_font)
    division.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _outline(division, 3)

    var outcome := _column(content, 0)
    outcome.custom_minimum_size.y = 164
    outcome.alignment = BoxContainer.ALIGNMENT_CENTER
    var stamp := _row(outcome, 3)
    stamp.alignment = BoxContainer.ALIGNMENT_CENTER
    var verdict_color := UI.GOLD_BRIGHT if player_won else (PAPER if not rival_won else Color("#ffb8a0"))
    var laurel_color := UI.GOLD if player_won or rival_won else Color("#b1a89b")
    Art.laurel(stamp, 49, laurel_color, false)
    var verdict := _label(stamp, result_text, 50, verdict_color, heading_font)
    verdict.name = "FightResultVerdict"
    _outline(verdict, 8)
    verdict.add_theme_color_override("font_shadow_color", Color("#6e361c"))
    verdict.add_theme_constant_override("shadow_offset_y", 3)
    Art.laurel(stamp, 49, laurel_color, true)
    var ending_round := int(summary.get("ending_round", 0))
    if ending_round > 0:
        var round_label := _label(outcome, "ROUND %d 종료" % ending_round, 12, PAPER, bold_font)
        round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _outline(round_label, 5)

    var match_row := _row(content, 7)
    _nameplate(match_row, str(boxer.get("name", "무명 복서")), player_status, RED, false)
    var vs := _label(match_row, "VS", 24, UI.GOLD_BRIGHT, UI.DISPLAY_FONT)
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _outline(vs, 6)
    _nameplate(match_row, opponent_name, opponent_status, BLUE, true)

func _portrait(parent: Control, texture: Texture2D, start: float, end: float, top: float, mirrored: bool, photo: bool, status: String) -> void:
    var portrait := _image(parent, texture, start, end, top, true)
    var material := ShaderMaterial.new()
    material.shader = PORTRAIT_SHADER
    material.set_shader_parameter("mirror_fade", mirrored)
    material.set_shader_parameter("fade_outer", not photo)
    material.set_shader_parameter("spotlight", 1.0 if status == "승리" else (0.12 if status == "패배" else 0.60))
    portrait.material = material
    portrait.resized.connect(func(): material.set_shader_parameter("portrait_size", portrait.size))

func _side_outcome(is_player: bool) -> String:
    if result_id.begins_with("WIN"):
        return "승리" if is_player else "패배"
    if result_id.begins_with("LOSS"):
        return "패배" if is_player else "승리"
    if result_id == "DRAW":
        return "무승부"
    return "내 선수" if is_player else "상대"

func _nameplate(parent: HBoxContainer, fighter_name: String, status: String, edge: Color, mirrored: bool) -> void:
    var panel := _frame(parent, STEEL, UI.GOLD if status == "승리" else edge.darkened(0.38), 2)
    panel.custom_minimum_size.y = 45
    var slashes := Control.new()
    slashes.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slashes.draw.connect(func():
        var w := slashes.size.x
        var h := slashes.size.y
        for index in range(3):
            var x := 21.0 + float(index) * 9.0 if mirrored else w - 11.0 - float(index) * 9.0
            var points := PackedVector2Array([Vector2(x - 7, 1), Vector2(x + 2, 1), Vector2(x - 14, h - 1), Vector2(x - 24, h - 1)])
            slashes.draw_colored_polygon(points, Color(edge, 0.13 + float(index) * 0.04))
    )
    panel.add_child(slashes)
    var inset := MarginContainer.new()
    inset.add_theme_constant_override("margin_left", 9)
    inset.add_theme_constant_override("margin_right", 9)
    panel.add_child(inset)
    var content := _column(inset, 0)
    var status_label := _label(content, status, 11, UI.GOLD_BRIGHT if status == "승리" else MUTED, bold_font)
    var title := _label(content, fighter_name, 15, PAPER, heading_font)
    for label in [status_label, title]:
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
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
    var table := _column(_frame(self, STEEL, UI.GOLD_DARK, 6), 1)
    _stat_row(table, &"opponent", "상대", opponent_name + "  /  " + weight_class)
    _stat_row(table, &"plan", "게임플랜", plan_name)
    if summary.has("purse"):
        _stat_row(table, &"money", "파이트머니", "%s원" % _signed_money(int(summary["purse"])), UI.GOLD_BRIGHT, 17)
    if summary.has("cycle_cost") and summary.has("purse"):
        var cost := int(summary["cycle_cost"])
        _stat_row(table, &"", "캠프 비용", "%s원  ·  잔액 변동 %s원" % [
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
        _stat_row(table, &"scores", "라운드 점수", "합계 %d:%d  ·  %s" % [player_total, opponent_total, "  ·  ".join(scores)])
    var previous: Dictionary = summary.get("previous", {})
    var points := int(career.get("career_points", 0))
    var points_line := "%d pt" % points
    if previous.has("career_points"):
        points_line += "  (%+d)" % (points - int(previous["career_points"]))
    _stat_row(table, &"career", "커리어 포인트", points_line, UI.GOLD_BRIGHT, 14)

    var rank := int(career.get("rank", 0))
    var ranking := "#%d" % rank
    var movement := 0
    if previous.has("rank"):
        var old_rank := int(previous["rank"])
        movement = old_rank - rank
        ranking = "#%d  →  #%d" % [old_rank, rank]
        if movement != 0:
            ranking += "  (%d계단 %s)" % [absi(movement), "상승" if movement > 0 else "하락"]
    _stat_row(table, &"rank", "랭킹", ranking, GREEN if movement > 0 else (RED if movement < 0 else UI.GOLD_BRIGHT), 14)

func _signed_money(value: int) -> String:
    return ("+" if value > 0 else "") + str(money_text.call(value))

func _stat_row(parent: VBoxContainer, icon: StringName, caption: String, value: String, tint: Color = PAPER, size: int = 12) -> void:
    if parent.get_child_count() > 0:
        _rule(parent, Color("#81643855"))
    var row := _row(parent, 7)
    row.custom_minimum_size.y = 23
    Art.result_icon(row, icon)
    var label := _label(row, caption, 11, UI.GOLD_BRIGHT, bold_font)
    label.custom_minimum_size.x = 78
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var divider := ColorRect.new()
    divider.custom_minimum_size.x = 1
    divider.color = Color("#81643863")
    row.add_child(divider)
    var data := _label(row, value, size, tint, bold_font, true)
    data.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    data.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _career_update() -> void:
    var previous: Dictionary = summary.get("previous", {})
    var row := _row(self, 6)
    var conditions := _column(_frame(row, STEEL, UI.GOLD_DARK, 7), 3)
    conditions.get_parent().size_flags_stretch_ratio = 1.34
    _section_title(conditions, &"condition", "컨디션 변화")
    _condition(conditions, "health", "건강", Color("#dc534a"), previous)
    _condition(conditions, "fatigue", "피로", Color("#499fe7"), previous)
    _label(conditions, "체중 %.2fkg" % float(boxer.get("weight_kg", 0.0)), 10, MUTED)

    var record := _column(_frame(row, STEEL, UI.GOLD_DARK, 7), 1)
    _section_title(record, &"career", "전적 업데이트")
    var ledger := _row(record, 3)
    ledger.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(ledger, 25, UI.GOLD, false)
    var score := _label(ledger, "%d승 %d패 %d무" % [int(career["wins"]), int(career["losses"]), int(career["draws"])], 19, UI.GOLD_BRIGHT, heading_font)
    score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    Art.laurel(ledger, 25, UI.GOLD, true)
    var bouts := _label(record, "%d경기" % int(career["fights"]), 10, MUTED)
    bouts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _section_title(parent: VBoxContainer, icon: StringName, title: String) -> void:
    var heading := _row(parent, 5)
    Art.result_icon(heading, icon)
    _label(heading, title, 12, UI.GOLD_BRIGHT, bold_font)
    _rule(parent, Color("#81643880"))

func _condition(parent: VBoxContainer, key: String, caption: String, tint: Color, previous: Dictionary) -> void:
    var row := _row(parent, 5)
    _label(row, caption, 11, PAPER, bold_font)
    var amount := int(boxer.get(key, 0))
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.value = amount
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.custom_minimum_size = Vector2(20, 6)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_theme_stylebox_override("background", UI.panel_style(Color("#232a30"), Color("#333b47"), 0))
    bar.add_theme_stylebox_override("fill", UI.panel_style(tint, tint.lightened(0.27), 0))
    row.add_child(bar)
    var text := "%d%%" % amount
    var change_color := PAPER
    if previous.has(key):
        var delta := amount - int(previous[key])
        text = "%d%% → %d%% (%+d)" % [int(previous[key]), amount, delta]
        if delta != 0:
            change_color = GREEN if (delta > 0) == (key == "health") else (RED if key == "health" else BLUE)
    var value := _label(row, text, 10, change_color, bold_font)
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _match_commentary() -> void:
    var line := ""
    var cards: Array = summary.get("round_cards", [])
    if result_id.ends_with("_KO") and int(summary.get("ending_round", 0)) > 0:
        line = "%d라운드에 %s의 KO로 경기가 끝났습니다." % [
            int(summary["ending_round"]), "내 선수" if result_id.begins_with("WIN") else "상대",
        ]
    elif not cards.is_empty():
        var ahead := 0
        var behind := 0
        var even := 0
        for card in cards:
            if card is Array and card.size() >= 2:
                var margin := int(card[0]) - int(card[1])
                ahead += int(margin > 0)
                behind += int(margin < 0)
                even += int(margin == 0)
        var rounds := ahead + behind + even
        if rounds > 0:
            line = "%d개 라운드 중 %d개에서 앞서고 %d개에서 뒤졌습니다." % [rounds, ahead, behind]
            if even > 0:
                line = "라운드별 채점 · 우세 %d / 열세 %d / 동점 %d" % [ahead, behind, even]
    if line.is_empty():
        return
    var row := _row(_frame(self, STEEL, UI.GOLD_DARK, 7), 6)
    Art.result_icon(row, &"commentary")
    var caption := _label(row, "경기 요약", 11, UI.GOLD_BRIGHT, bold_font)
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var copy := _label(row, line, 11, PAPER, bold_font, true)
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _continue_button() -> void:
    var footer := CenterContainer.new()
    footer.custom_minimum_size.y = 79
    add_child(footer)
    var lighting := Control.new()
    lighting.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lighting.custom_minimum_size = Vector2(346, 79)
    footer.add_child(lighting)
    Art.glow(lighting, Vector2(0.5, 0.15), Vector2(316, 27), Color(1, 0.61, 0.25, 0.8))
    Art.glow(lighting, Vector2(0.5, 0.84), Vector2(325, 22), Color(1, 0.53, 0.20, 0.65))
    var next := UI.action_button("커리어 계속  »", heading_font, true)
    next.name = "FightResultContinue"
    next.custom_minimum_size = Vector2(304, 54)
    next.add_theme_font_size_override("font_size", 22)
    next.add_theme_stylebox_override("normal", Art.gold_plate(304, 54, Color("#cd9039"), 4))
    next.add_theme_stylebox_override("hover", Art.gold_plate(304, 54, Color("#e5ad50"), 4))
    next.add_theme_stylebox_override("pressed", Art.gold_plate(304, 54, Color("#ab6a28"), 4))
    next.add_theme_stylebox_override("disabled", Art.gold_plate(304, 54, Color("#746347"), 4))
    next.pressed.connect(func():
        if not next.disabled and not is_queued_for_deletion():
            next.disabled = true
            continue_requested.emit()
    )
    footer.add_child(next)

func _rule(parent: VBoxContainer, color: Color) -> void:
    var rule := ColorRect.new()
    rule.color = color
    rule.custom_minimum_size.y = 1
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(rule)

func _outline(label: Label, stroke: int) -> void:
    label.add_theme_color_override("font_outline_color", INK)
    label.add_theme_constant_override("outline_size", stroke)

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
