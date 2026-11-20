extends VBoxContainer

signal action_chosen(id: String)
signal settlement_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const ACTION_ART := preload("res://assets/visual/reference_v1/battle_actions.png")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const INK := Color("#09131e")
const PAPER := Color("#f7f4ec")
const MUTED := Color("#c1cbd4")
const RED := Color("#e54e47")
const BLUE := Color("#53aefa")

var stage: FightStage
var snapshot: Dictionary
var telegraph: Dictionary
var player_name: String
var opponent_name: String
var player_style: String
var opponent_style: String
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
        _feedback()
        var settle := UI.action_button("경기 정산", bold_font, true)
        settle.name = "FightSettlement"
        settle.pressed.connect(func():
            if not is_queued_for_deletion():
                settlement_requested.emit()
        )
        add_child(settle)
    else:
        _tactical_read()
        _feedback()
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
    var title := _label(stack, "FIGHT NIGHT", 30, PAPER, heading_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var plaque := _panel(stack, Color("#d6a554"), UI.GOLD_BRIGHT, 1)
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var round_label := _label(plaque, "ROUND %d / %d" % [int(snapshot["round"]), round_count], 17, INK, heading_font)
    round_label.name = "FightRoundLabel"
    round_label.custom_minimum_size.x = 153
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var meta := _label(stack, "%s  ·  교환 %d / %d" % [weight_class, exchange_in_round, exchanges_per_round], 10, PAPER, bold_font)
    meta.name = "FightExchangeLabel"
    meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _corner_hud() -> void:
    var row := _row(self, 5)
    row.name = "V19CornerHUD"
    _corner(row, player_name, player_style, "Player", float(snapshot["player_hp"]), float(snapshot["player_stamina"]), RED)
    var versus := _label(row, "VS", 18, UI.GOLD_BRIGHT, heading_font)
    versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _corner(row, opponent_name, opponent_style, "Opponent", float(snapshot["opponent_hp"]), float(snapshot["opponent_stamina"]), BLUE)

func _corner(parent: HBoxContainer, fighter_name: String, style: String, side: String, hp: float, stamina: float, color: Color) -> void:
    var panel := _panel(parent, INK.lerp(color, 0.06), color.lightened(0.16), 6)
    var box := _column(panel, 2)
    var title := _label(box, fighter_name, 16, PAPER, heading_font)
    title.clip_text = true
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _meter(box, "HP", hp, RED, "Fight" + side + "Health")
    _meter(box, "STA", stamina, BLUE, "Fight" + side + "Stamina")
    _label(box, style, 10, MUTED, bold_font)

func _meter(parent: VBoxContainer, caption: String, value: float, tint: Color, node_name: String) -> void:
    var row := _row(parent, 4)
    var name_label := _label(row, caption, 10, PAPER, bold_font)
    name_label.custom_minimum_size.x = 22
    var meter := ProgressBar.new()
    meter.name = node_name
    meter.step = 0.0
    meter.value = value
    meter.show_percentage = false
    meter.custom_minimum_size.y = 7
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.add_theme_stylebox_override("background", UI.panel_style(Color("#26323e"), Color("#26323e"), 0))
    meter.add_theme_stylebox_override("fill", UI.panel_style(tint, tint, 0))
    row.add_child(meter)
    var amount := _label(row, "%d / 100" % roundi(value), 10, PAPER, bold_font)
    amount.name = node_name + "Value"
    amount.custom_minimum_size.x = 43
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _tactical_read() -> void:
    var panel := _panel(self, INK, UI.GOLD_DARK, 5)
    panel.name = "V19TacticalRead"
    var row := _row(panel, 8)
    var lead := _label(row, "상대 읽기\n%d%%" % int(telegraph.get("confidence", 0)), 13, UI.GOLD_BRIGHT, bold_font)
    lead.custom_minimum_size.x = 72
    lead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var detail := _column(row, 1)
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(detail, str(telegraph.get("copy", CombatPresentation.telegraph_title(telegraph))), 10, PAPER, null, true)
    _label(detail, "코너 조언 · " + advice, 10, MUTED, null, true)

func _feedback() -> void:
    var box := _panel(self, Color("#220f13"), Color("#cc6452"), 5)
    var previous: Dictionary = snapshot.get("last_exchange", {})
    var text := CombatPresentation.telegraph_title(telegraph)
    if not previous.is_empty():
        text = CombatPresentation.exchange_headline(previous)
        if bool(previous.get("round_ended", false)):
            var card: Array = previous.get("round_card", [])
            if card.size() >= 2:
                text = "ROUND %d 종료  ·  %d : %d" % [int(previous["completed_round"]), int(card[0]), int(card[1])]
    var caption := _label(box, text, 14, UI.GOLD_BRIGHT, heading_font, true)
    caption.name = "FightEventLabel"
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _action_row() -> void:
    var row := _row(self, 4)
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
        var tint := UI.GOLD_BRIGHT if bool(action["recommended"]) else Color("#aa895b")
        for state in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
            button.add_theme_color_override(state, PAPER)
        button.add_theme_stylebox_override("normal", UI.beveled_panel_style(INK, tint, 4))
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
