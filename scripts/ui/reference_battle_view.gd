extends VBoxContainer

signal action_chosen(id: String)
signal settlement_requested()
signal tutorial_skipped()

const UI := preload("res://scripts/ui/reference_ui.gd")
const ACTION_ART := preload("res://assets/visual/reference_v1/battle_actions.png")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const INK := Color("#09131e")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#c1cbd4")
const RED := Color("#e54e47")
const BLUE := Color("#49a8ec")
const PREDICTIONS := {
    "lead_hand": "잽 또는 거리 재기 가능성",
    "committed_attack": "큰 공격 가능성",
    "level_change": "바디 공격 가능성",
    "defensive_shell": "가드 유지 가능성",
    "counter_wait": "반격 대기 가능성",
}

var stage: FightStage
var snapshot: Dictionary
var telegraph: Dictionary
var show_first_exchange_guide := false
var tutorial_target_action := ""
var tutorial_hint := ""
var player_name: String
var opponent_name: String
var player_style: String
var opponent_style: String
var player_trait: String
var player_rank: int
var opponent_rank: int
var round_count: int
var exchange_in_round: int
var exchanges_per_round: int
var weight_class: String
var actions: Array[Dictionary] = []
var advice: String
var heading_font: Font
var bold_font: Font

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 6)
    _heading()
    var ring := Control.new()
    ring.name = "FightRingFrame"
    ring.custom_minimum_size = stage.custom_minimum_size
    ring.clip_contents = true
    add_child(ring)
    ring.add_child(stage)
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _corner_hud()
    if bool(snapshot["finished"]):
        _finish_feedback()
        var settle := UI.action_button("경기 정산", bold_font, true)
        settle.name = "FightSettlement"
        settle.pressed.connect(func():
            if not is_queued_for_deletion():
                settlement_requested.emit()
        )
        add_child(settle)
    else:
        _tactical_read()
        _prediction()
        _action_row()

func _heading() -> void:
    var panel := _panel(self, INK, UI.GOLD_DARK, 4)
    panel.name = "V19RoundStrip"
    var backdrop := Control.new()
    backdrop.clip_contents = true
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(backdrop)
    for right in [false, true]:
        var lights := TextureRect.new()
        lights.texture = LIGHTS
        lights.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        lights.stretch_mode = TextureRect.STRETCH_SCALE
        lights.flip_h = right
        lights.modulate.a = 0.73
        lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
        backdrop.add_child(lights)
        lights.anchor_left = 0.68 if right else 0.0
        lights.anchor_right = 1.0 if right else 0.32
        lights.anchor_bottom = 1.0
    var stack := _column(panel, 1)
    var title := _label(stack, "FIGHT NIGHT", 37, PAPER, UI.DISPLAY_FONT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var plaque := _panel(stack, Color("#d6a554"), UI.GOLD_BRIGHT, 1)
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var round_label := _label(plaque, "ROUND %d / %d" % [int(snapshot["round"]), round_count], 20, INK, UI.DISPLAY_FONT)
    round_label.name = "FightRoundLabel"
    round_label.custom_minimum_size.x = 153
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var track := _row(stack, 5)
    track.alignment = BoxContainer.ALIGNMENT_CENTER
    var meta := _label(track, "%s  ·  교환 %d / %d" % [weight_class, exchange_in_round, exchanges_per_round], 10, PAPER, bold_font)
    meta.name = "FightExchangeLabel"
    for exchange in range(1, exchanges_per_round + 1):
        var step := ColorRect.new()
        step.name = "FightExchangeStep%d" % exchange
        step.custom_minimum_size = Vector2(13, 4)
        step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        step.color = UI.GOLD_BRIGHT if exchange == exchange_in_round else UI.GOLD_DARK if exchange < exchange_in_round else Color("#394552")
        track.add_child(step)

func _corner_hud() -> void:
    var row := _row(self, 5)
    row.name = "V19CornerHUD"
    _corner(row, player_name, player_style, player_trait, "내 선수", player_rank, "Player", RED)
    var versus := _label(row, "VS", 21, UI.GOLD_BRIGHT, UI.DISPLAY_FONT)
    versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _corner(row, opponent_name, opponent_style, "", "상대", opponent_rank, "Opponent", BLUE)

func _corner(parent: HBoxContainer, fighter_name: String, style: String, trait_text: String, role: String, rank: int, side: String, color: Color) -> void:
    var panel := _panel(parent, INK.lerp(color, 0.06), color.lightened(0.16), 6)
    var box := _column(panel, 2)
    var badges := _row(box, 4)
    var side_label := _label(badges, role, 9, color.lightened(0.34), bold_font)
    side_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if rank > 0:
        _label(badges, "#%d" % rank, 9, MUTED, bold_font)
    var title := _label(box, fighter_name, 16, PAPER, heading_font)
    title.clip_text = true
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var key := "player" if side == "Player" else "opponent"
    _meter(box, "HP", float(snapshot[key + "_hp"]), RED, "Fight" + side + "Health")
    _meter(box, "STA", float(snapshot[key + "_stamina"]), BLUE, "Fight" + side + "Stamina")
    var info := "스타일 " + style
    if not trait_text.is_empty():
        info += "  ·  " + trait_text
    var style_label := _label(box, info, 9, MUTED, bold_font)
    style_label.clip_text = true
    style_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _meter(parent: VBoxContainer, caption: String, value: float, tint: Color, node_name: String) -> void:
    var row := _row(parent, 4)
    var name_label := _label(row, caption, 10, PAPER, bold_font)
    name_label.custom_minimum_size.x = 23
    var meter := _bar(row, value, tint, 13)
    meter.name = node_name
    var amount := _label(meter, "%d / 100" % roundi(value), 9, PAPER, bold_font)
    amount.name = node_name + "Value"
    amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    amount.add_theme_color_override("font_outline_color", INK)
    amount.add_theme_constant_override("outline_size", 4)
    amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    amount.offset_right = -4

func _bar(parent: HBoxContainer, value: float, tint: Color, height: float) -> ProgressBar:
    var meter := ProgressBar.new()
    meter.step = 0.0
    meter.value = value
    meter.show_percentage = false
    meter.custom_minimum_size.y = height
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.add_theme_stylebox_override("background", UI.panel_style(Color("#26323e"), Color("#26323e"), 0))
    meter.add_theme_stylebox_override("fill", UI.panel_style(tint, tint, 0))
    parent.add_child(meter)
    return meter

func _tactical_read() -> void:
    var edge := UI.GOLD_BRIGHT if show_first_exchange_guide else UI.GOLD_DARK
    var panel := _panel(self, INK, edge, 8)
    panel.name = "V19TacticalRead"
    var row := _row(panel, 8)
    var read := _column(row, 2)
    read.custom_minimum_size.x = 83
    _label(read, "상대 읽기", 13, UI.GOLD_BRIGHT, bold_font)
    var confidence := _row(read, 3)
    var amount := clampi(int(telegraph.get("confidence", 0)), 0, 100)
    var trust := _label(confidence, "%d%%" % amount, 10, UI.GOLD_BRIGHT, bold_font)
    trust.name = "FightReadConfidence"
    _bar(confidence, amount, UI.GOLD, 4)
    var detail := _column(row, 4)
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(detail, str(telegraph.get("copy", CombatPresentation.telegraph_title(telegraph))), 10, PAPER, null, true)
    _label(detail, "코너 조언 · " + advice, 10, MUTED, null, true)

func _prediction() -> void:
    var panel := _panel(self, Color("#220f13"), Color("#cc6452"), 8)
    var content := _column(panel, 1)
    var row := _row(content, 8)
    var caption := _label(row, "상대 행동 예측", 10, Color("#f0b4a4"), bold_font)
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var signal_id := str(telegraph.get("signal_id", ""))
    var guess := str(PREDICTIONS.get(signal_id, "움직임을 관찰 중"))
    var forecast := _label(row, guess, 14, UI.GOLD_BRIGHT, heading_font, true)
    forecast.name = "FightPrediction"
    forecast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var result := _last_exchange_text()
    if not tutorial_hint.is_empty():
        var tutorial_row := _row(content, 4)
        var tip := _label(tutorial_row, tutorial_hint, 11, UI.GOLD_BRIGHT, bold_font, true)
        tip.name = "FirstBoutFightGuide"
        tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var skip := Button.new()
        skip.name = "FirstBoutFightGuideSkip"
        skip.text = "끄기"
        skip.custom_minimum_size = Vector2(46, 30)
        skip.pressed.connect(func(): tutorial_skipped.emit())
        tutorial_row.add_child(skip)
    elif not result.is_empty():
        var update := _label(content, result, 10, MUTED)
        update.name = "FightEventLabel"

func _last_exchange_text() -> String:
    var previous: Dictionary = snapshot.get("last_exchange", {})
    if previous.is_empty():
        return ""
    if bool(previous.get("round_ended", false)):
        var card: Array = previous.get("round_card", [])
        if card.size() >= 2:
            return "ROUND %d 종료  ·  %d : %d" % [int(previous["completed_round"]), int(card[0]), int(card[1])]
    return "직전 교환 · " + CombatPresentation.exchange_headline(previous)

func _finish_feedback() -> void:
    var box := _panel(self, Color("#220f13"), Color("#cc6452"), 5)
    var outcome := _last_exchange_text()
    var caption := _label(box, outcome if not outcome.is_empty() else "경기 종료", 14, UI.GOLD_BRIGHT, heading_font, true)
    caption.name = "FightEventLabel"
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _action_row() -> void:
    var row := _row(self, 5)
    row.name = "V19FightActions"
    for index in range(actions.size()):
        var action := actions[index]
        var id := str(action["id"])
        var stamina := int(action["stamina"])
        var button := Button.new()
        button.name = "FightAction_" + id
        button.text = "%s\n%s" % [
            action["label"], "회복 +%d" % abs(stamina) if stamina < 0 else "소모 %d" % stamina,
        ]
        button.custom_minimum_size = Vector2(0, 132)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.mouse_filter = Control.MOUSE_FILTER_PASS
        button.add_theme_font_override("font", bold_font)
        button.add_theme_font_size_override("font_size", 13)
        var highlighted := id == tutorial_target_action
        var tint := UI.GOLD_BRIGHT if highlighted else Color("#aa895b")
        for state in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
            button.add_theme_color_override(state, PAPER)
        button.add_theme_stylebox_override("normal", UI.beveled_panel_style(Color("#3b2b12") if highlighted else INK, tint, 4))
        button.add_theme_stylebox_override("hover", UI.beveled_panel_style(Color("#172637"), tint, 4))
        button.add_theme_stylebox_override("pressed", UI.beveled_panel_style(Color("#352417"), UI.GOLD_BRIGHT, 4))
        button.add_theme_stylebox_override("disabled", UI.beveled_panel_style(INK, Color("#5b6270"), 4))
        var art := AtlasTexture.new()
        art.atlas = ACTION_ART
        art.region = Rect2(index * 150, 0, 150, 143)
        art.filter_clip = true
        button.icon = art
        button.expand_icon = true
        button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
        button.add_theme_constant_override("icon_max_width", 67)
        button.pressed.connect(func():
            if not is_queued_for_deletion() and not button.disabled:
                action_chosen.emit(id)
        )
        row.add_child(button)

func _panel(parent: Container, color: Color, edge: Color, margin: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(color, edge, margin))
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

func _label(parent: Control, text: String, points: int, color: Color, font: Font = null, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label
