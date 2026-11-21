extends VBoxContainer

signal style_chosen(style_id: String)
signal talent_confirmed()
signal style_reselect_requested()
signal talent_picker_requested()
signal talent_chosen(talent_id: String)
signal talent_picker_cancelled()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const LIGHTS := preload("res://assets/visual/reference_v1/offer_lights.png")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const BALANCED_ART := preload("res://assets/visual/reference_v1/title_boxer.webp")
const TACTICAL_ART := preload("res://assets/visual/reference_v1/tactical_art.png")
const ACTION_ART := preload("res://assets/visual/reference_v1/battle_actions.png")
const TACTICAL_ROWS := {"out_boxer": 0, "counter_puncher": 2, "pressure_fighter": 3}
const STATS := {
    "power": "파워",
    "speed": "스피드",
    "technique": "테크닉",
    "defense": "수비",
    "conditioning": "체력",
}
const INK := Color("#09121b")
const PANEL := Color("#131c26")
const PAPER := Color("#f7f3e8")
const MUTED := Color("#c1cbd4")
const GREEN := Color("#9ddfa9")
const RED := Color("#f2a091")

var choosing_style := true
var choosing_talent := false
var styles: Array
var talents: Array
var boxer: Dictionary
var talent: Dictionary
var stat_help: Dictionary
var heading_font: Font
var bold_font: Font

var _submitted := false
var _style_order: Array[String] = []
var _style_cards: Dictionary = {}
var _style_walkthrough_rows: Dictionary = {}
var _style_walkthrough_labels: Dictionary = {}
var _style_walkthrough_buttons: Dictionary = {}
var _style_walkthrough_index := 0
var _style_guide_title: Label
var _style_guide_body: Label
var _style_guide_replay: Button

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 6)
    _masthead()
    if choosing_style:
        _style_picker()
    elif choosing_talent:
        _talent_picker()
    else:
        _talent_reveal()

func _masthead() -> void:
    var frame := _panel(self, UI.GOLD_DARK, 3)
    var art := Control.new()
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.clip_contents = true
    frame.add_child(art)
    for side in [0, 1]:
        var lamp := _picture(art, LIGHTS)
        lamp.anchor_left = 0.0 if side == 0 else 0.73
        lamp.anchor_right = 0.27 if side == 0 else 1.0
        lamp.anchor_bottom = 1.0
        lamp.flip_h = side == 1
        lamp.modulate.a = 0.59

    var stack := _column(frame, 1)
    var line := _row(stack, 5)
    line.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(line, 31, UI.GOLD, false)
    _label(line, "BOXER CREATION" if choosing_style else "NATURAL TALENT", 34, PAPER, UI.DISPLAY_FONT)
    Art.laurel(line, 31, UI.GOLD, true)
    var plaque := PanelContainer.new()
    plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    plaque.add_theme_stylebox_override("panel", Art.gold_plate(166, 25, Color("#c28b40"), 2))
    stack.add_child(plaque)
    var step := _label(plaque, "1 / 2   복싱 스타일 선택" if choosing_style else "2 / 2   타고난 재능", 13, INK, bold_font)
    step.custom_minimum_size = Vector2(162, 22)
    step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _style_picker() -> void:
    var navigation := _row(self, 7)
    var previous := _secondary_action("‹ 이전", 12, 48)
    previous.name = "StylePrevious"
    previous.pressed.connect(_browse_style.bind(-1))
    navigation.add_child(previous)
    var instruction := _label(navigation, "스타일을 둘러보고 선택하세요", 12, UI.GOLD_BRIGHT, bold_font, true)
    instruction.name = "BoxerStyleIntro"
    instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var next := _action("다음 ›", 12, 48)
    next.name = "StyleNext"
    next.pressed.connect(_browse_style.bind(1))
    navigation.add_child(next)
    for style: Dictionary in styles:
        _style_order.append(str(style.get("id", "")))
        _style_card(style)
    _style_walkthrough_index = 0
    _show_browsed_style()


func _browse_style(direction: int) -> void:
    if _style_order.is_empty():
        return
    _style_walkthrough_index = wrapi(_style_walkthrough_index + direction, 0, _style_order.size())
    _show_browsed_style()
    call_deferred("_scroll_style_picker_to_top")


func _show_browsed_style() -> void:
    for index in range(_style_order.size()):
        var card: PanelContainer = _style_cards[_style_order[index]]
        card.visible = index == _style_walkthrough_index
        card.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL, UI.GOLD_BRIGHT, 6))

func _style_card(style: Dictionary) -> void:
    var id := str(style.get("id", ""))
    var card := _panel(self)
    card.name = "BoxerStyleCard_" + id
    _style_cards[id] = card
    var content := _column(card, 4)
    var row := _row(content, 7)
    var thumbnail := _picture(row, _style_art(id))
    thumbnail.custom_minimum_size = Vector2(76, 74)

    var info := _column(row, 1)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(info, str(style.get("name", "")), 19, PAPER, heading_font)
    _label(info, str(style.get("signature", "")), 11, MUTED, null, true)
    var description := _label(info, str(style.get("description", "")), 11, PAPER, null, true)
    description.name = "BoxerStyleDescription_" + id
    description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var effect_title := _label(info, "시작 능력치 보정", 10, UI.GOLD_BRIGHT, bold_font)
    effect_title.name = "BoxerStyleEffectTitle_" + id
    var changes := _stat_changes(info, style.get("stat_bonus", {}))
    changes.name = "BoxerStyleBonuses_" + id
    if changes.get_child_count() == 0:
        _label(changes, "시작 능력치 보정 없음", 10, MUTED, bold_font)

    var guide_row := _row(content, 4)
    guide_row.name = "BoxerStyleWalkthrough_" + id
    guide_row.visible = false
    _style_walkthrough_rows[id] = guide_row
    var guide_label := _label(guide_row, "설명", 10, UI.GOLD_BRIGHT, bold_font)
    guide_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_walkthrough_labels[id] = guide_label
    var next_style := _action("다음 스타일 ›", 11, 36)
    next_style.name = "BoxerStyleNext_" + id
    next_style.custom_minimum_size.x = 116
    next_style.pressed.connect(_advance_style_walkthrough.bind(id))
    guide_row.add_child(next_style)
    _style_walkthrough_buttons[id] = next_style
    var end_guide := _secondary_action("안내 건너뛰기", 10, 36)
    end_guide.name = "BoxerStyleGuideSkip_" + id
    end_guide.custom_minimum_size.x = 96
    end_guide.pressed.connect(_skip_style_walkthrough)
    guide_row.add_child(end_guide)

    var choose := _action("선택", 14, 48)
    choose.name = "BoxerStyle_" + id
    choose.custom_minimum_size.x = 73
    choose.size_flags_horizontal = Control.SIZE_SHRINK_END
    choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var hint := str(style.get("description", ""))
    choose.tooltip_text = str(style.get("name", "")) + " · " + hint
    choose.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            style_chosen.emit(id)
    )
    row.add_child(choose)

func _advance_style_walkthrough(style_id: String) -> void:
    if _style_walkthrough_index < 0 or _style_walkthrough_index >= _style_order.size():
        return
    if style_id != _style_order[_style_walkthrough_index]:
        return
    if _style_walkthrough_index >= _style_order.size() - 1:
        _style_walkthrough_index = -1
        _update_style_walkthrough()
        call_deferred("_scroll_style_picker_to_top")
        return
    _style_walkthrough_index += 1
    _update_style_walkthrough()
    call_deferred("_ensure_active_style_visible")

func _skip_style_walkthrough() -> void:
    _style_walkthrough_index = -1
    _update_style_walkthrough()
    call_deferred("_scroll_style_picker_to_top")

func _replay_style_walkthrough() -> void:
    if _style_order.is_empty():
        return
    _style_walkthrough_index = 0
    _update_style_walkthrough()
    call_deferred("_ensure_active_style_visible")

func _update_style_walkthrough() -> void:
    var walkthrough_active := _style_walkthrough_index >= 0 and _style_walkthrough_index < _style_order.size()
    if walkthrough_active:
        var style_id := _style_order[_style_walkthrough_index]
        var style_name := ""
        for style: Dictionary in styles:
            if str(style.get("id", "")) == style_id:
                style_name = str(style.get("name", ""))
                break
        _style_guide_title.text = "스타일 설명 %d / %d · %s" % [_style_walkthrough_index + 1, _style_order.size(), style_name]
        _style_guide_body.text = "금색 테두리 카드가 지금 설명하는 스타일입니다. 오른쪽 [선택]으로 고르면 2/2단계에서 타고난 재능을 확인합니다. [다음 스타일]은 다음 카드를 보여줍니다."
    else:
        _style_guide_title.text = "원하는 복싱 스타일을 선택하세요"
        _style_guide_body.text = "이 단계는 선수의 경기 성향과 시작 능력치 보정을 정합니다. 마음에 드는 카드의 [선택]을 누르면 2/2단계에서 타고난 재능을 확인합니다."
    _style_guide_replay.visible = not walkthrough_active

    for style_id: String in _style_order:
        var card: PanelContainer = _style_cards[style_id]
        var active := walkthrough_active and style_id == _style_order[_style_walkthrough_index]
        card.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL, UI.GOLD_BRIGHT if active else UI.GOLD_DARK, 6))
        var guide_row: HBoxContainer = _style_walkthrough_rows[style_id]
        guide_row.visible = active
        if active:
            var guide_label: Label = _style_walkthrough_labels[style_id]
            guide_label.text = "현재 안내 중 · %d/%d" % [_style_walkthrough_index + 1, _style_order.size()]
            var next_style: Button = _style_walkthrough_buttons[style_id]
            next_style.text = "안내 끝내기" if _style_walkthrough_index == _style_order.size() - 1 else "다음 스타일 ›"

func _ensure_active_style_visible() -> void:
    if _style_walkthrough_index < 0 or _style_walkthrough_index >= _style_order.size():
        return
    var card: Control = _style_cards[_style_order[_style_walkthrough_index]]
    var ancestor := get_parent()
    while ancestor != null and not ancestor is ScrollContainer:
        ancestor = ancestor.get_parent()
    if ancestor is ScrollContainer:
        ancestor.ensure_control_visible(card)

func _scroll_style_picker_to_top() -> void:
    var ancestor := get_parent()
    while ancestor != null and not ancestor is ScrollContainer:
        ancestor = ancestor.get_parent()
    if ancestor is ScrollContainer:
        ancestor.scroll_vertical = 0

func _stat_guide() -> void:
    var guide := _column(_panel(self), 2)
    var heading := _label(guide, "능력치 뜻 · 기본 50에서 보정 (1~100)", 12, UI.GOLD_BRIGHT, bold_font)
    heading.name = "BoxerStatGuide"
    for stat: String in STATS:
        var row := _row(guide, 6)
        var label: String = "체력(지구력)" if stat == "conditioning" else STATS[stat]
        var stat_name := _label(row, label, 11, PAPER, bold_font)
        stat_name.custom_minimum_size.x = 72 if stat == "conditioning" else 58
        var meaning := _label(row, str(stat_help.get(stat, "")), 11, MUTED, null, true)
        meaning.name = "BoxerStatHelp_" + stat
        meaning.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _talent_reveal() -> void:
    var frame := _panel(self, UI.GOLD, 2)
    var scene := Control.new()
    scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene.clip_contents = true
    frame.add_child(scene)
    var arena_crop := AtlasTexture.new()
    arena_crop.atlas = RING
    arena_crop.region = Rect2(0, 0, 941, 465)
    arena_crop.filter_clip = true
    var image := _picture(scene, arena_crop)
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    Art.glow(scene, Vector2(0.50, 0.81), Vector2(465, 167), Color(0.015, 0.025, 0.037, 0.97))
    Art.glow(scene, Vector2(0.50, 0.96), Vector2(292, 15), Color(1.0, 0.63, 0.25, 0.70))

    var nameplate := _column(frame, 0)
    nameplate.custom_minimum_size.y = 182
    nameplate.alignment = BoxContainer.ALIGNMENT_END
    var headline := _row(nameplate, 8)
    headline.alignment = BoxContainer.ALIGNMENT_CENTER
    Art.laurel(headline, 35, UI.GOLD, false)
    var talent_name := str(talent.get("name", boxer.get("trait_name", "무특성")))
    var title := _label(headline, talent_name, 34, UI.GOLD_BRIGHT, heading_font)
    title.name = "BoxerTalentName"
    title.add_theme_color_override("font_outline_color", INK)
    title.add_theme_constant_override("outline_size", 7)
    Art.laurel(headline, 35, UI.GOLD, true)

    var details := _column(_panel(self), 3)
    _label(details, "재능 효과", 15, UI.GOLD_BRIGHT, heading_font)
    _label(details, str(talent.get("description", "이 선수만의 타고난 장단점입니다.")), 13, PAPER, null, true)
    _stat_changes(details, talent.get("stat_bonus", {}))
    _label(details, "이 선수의 재능은 커리어 동안 유지됩니다.", 11, MUTED)

    var change_talent := _secondary_action("재능 다시 선택", 14, 48)
    change_talent.name = "BoxerReselectTalent"
    change_talent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    change_talent.tooltip_text = "커리어를 시작하기 전에 타고난 재능을 바꿉니다."
    change_talent.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            talent_picker_requested.emit()
    )
    add_child(change_talent)

    var reselect := _secondary_action("복싱 스타일 다시 선택", 14, 48)
    reselect.name = "BoxerReselectStyle"
    reselect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reselect.tooltip_text = "스타일 선택으로 돌아가 다른 복싱 스타일을 고릅니다."
    reselect.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            style_reselect_requested.emit()
    )
    add_child(reselect)

    var stats := _column(_panel(self), 3)
    var heading := _row(stats, 5)
    var caption := _label(heading, "시작 능력치", 16, PAPER, heading_font)
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style_chip := _label(heading, "복싱 스타일   " + str(boxer.get("identity_name", "균형형")), 12, UI.GOLD_BRIGHT, bold_font)
    style_chip.name = "BoxerChosenStyle"
    style_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    for stat: String in STATS:
        _stat_meter(stats, stat)

    var begin := _action("이 복서로 커리어 시작  »", 21, 60)
    begin.name = "BoxerBeginCareer"
    begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    begin.custom_minimum_size.x = 318
    begin.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            talent_confirmed.emit()
    )
    add_child(begin)

func _talent_picker() -> void:
    var guidance := _column(_panel(self), 2)
    var title := _label(guidance, "타고난 재능을 선택하세요", 15, UI.GOLD_BRIGHT, heading_font)
    title.name = "BoxerTalentPickerTitle"
    var instructions := _label(guidance, "재능을 고르면 시작 능력치와 커리어 특성이 바뀝니다. 원하는 재능의 [이 재능 선택]을 누르세요. 커리어를 시작하기 전에는 언제든 다시 바꿀 수 있습니다.", 12, MUTED, null, true)
    instructions.name = "BoxerTalentPickerInstructions"

    var current_id := str(boxer.get("trait_id", ""))
    for talent_value: Dictionary in talents:
        var id := str(talent_value.get("id", ""))
        var is_current := id == current_id
        var card := _panel(self, UI.GOLD_BRIGHT if is_current else UI.GOLD_DARK, 7)
        card.name = "BoxerTalentCard_" + id
        var content := _column(card, 3)
        var heading := _row(content, 5)
        var name := _label(heading, str(talent_value.get("name", "")), 19, PAPER, heading_font)
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if is_current:
            _label(heading, "현재 선택", 11, UI.GOLD_BRIGHT, bold_font)
        _label(content, str(talent_value.get("description", "")), 12, MUTED, null, true)
        _stat_changes(content, talent_value.get("stat_bonus", {}))
        var choose := _action("현재 선택됨" if is_current else "이 재능 선택", 13, 44)
        choose.name = "TalentSelect_" + id
        choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choose.disabled = is_current
        choose.pressed.connect(_select_talent.bind(id))
        content.add_child(choose)

    var back := _secondary_action("재능 화면으로 돌아가기", 13, 48)
    back.name = "BoxerTalentPickerBack"
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(func():
        if not _submitted and not is_queued_for_deletion():
            _submitted = true
            talent_picker_cancelled.emit()
    )
    add_child(back)

func _select_talent(talent_id: String) -> void:
    if not _submitted and not is_queued_for_deletion():
        _submitted = true
        talent_chosen.emit(talent_id)

func _stat_changes(parent: VBoxContainer, bonuses: Dictionary) -> HFlowContainer:
    var changes := HFlowContainer.new()
    changes.add_theme_constant_override("h_separation", 5)
    changes.add_theme_constant_override("v_separation", 0)
    parent.add_child(changes)
    for stat: String in STATS:
        var value := int(bonuses.get(stat, 0))
        if value != 0:
            var change := _label(changes, "%s %+d" % [STATS[stat], value], 10, GREEN if value > 0 else RED, bold_font)
            change.tooltip_text = "%s 시작 보정" % STATS[stat]
    return changes

func _stat_meter(parent: VBoxContainer, stat: String) -> void:
    var row := _row(parent, 7)
    var label := _label(row, STATS[stat], 12, MUTED, bold_font)
    label.custom_minimum_size.x = 54
    var amount := int(boxer.get(stat, 0))
    var meter := ProgressBar.new()
    meter.custom_minimum_size = Vector2(0, 6)
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    meter.show_percentage = false
    meter.value = amount
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meter.add_theme_stylebox_override("background", UI.panel_style(Color("#253140"), Color("#34404e"), 0))
    meter.add_theme_stylebox_override("fill", UI.panel_style(Color("#c5914d"), UI.GOLD, 0))
    row.add_child(meter)
    var value := _label(row, str(amount), 13, PAPER, bold_font)
    value.name = "BoxerStat_" + stat
    value.custom_minimum_size.x = 24
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style_art(id: String) -> Texture2D:
    if id in TACTICAL_ROWS:
        var art := AtlasTexture.new()
        art.atlas = TACTICAL_ART
        art.region = Rect2(0, int(TACTICAL_ROWS[id]) * 108, 216, 108)
        art.filter_clip = true
        return art
    if id == "slugger":
        var art := AtlasTexture.new()
        art.atlas = ACTION_ART
        art.region = Rect2(150, 0, 150, 145)
        art.filter_clip = true
        return art
    return BALANCED_ART

func _action(text: String, size: int, height: int) -> Button:
    var button := UI.action_button(text, heading_font, true)
    button.custom_minimum_size.y = height
    button.add_theme_font_size_override("font_size", size)
    for state in ["normal", "hover", "pressed"]:
        var tone := Color("#ca9043")
        if state == "hover":
            tone = Color("#e2ab5b")
        elif state == "pressed":
            tone = Color("#9e652c")
        button.add_theme_stylebox_override(state, Art.gold_plate(146, height, tone, 3))
    return button

func _secondary_action(text: String, size: int, height: int) -> Button:
    var button := UI.action_button(text, heading_font)
    button.custom_minimum_size.y = height
    button.add_theme_font_size_override("font_size", size)
    for state in ["normal", "hover", "pressed"]:
        var background := Color("#151d27")
        var edge := Color("#665336")
        if state == "hover":
            edge = UI.GOLD
        elif state == "pressed":
            background = Color("#10161c")
        button.add_theme_stylebox_override(state, UI.beveled_panel_style(background, edge, 5))
    return button

func _panel(parent: Container, edge: Color = UI.GOLD_DARK, padding: int = 6) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(PANEL, edge, padding))
    parent.add_child(panel)
    return panel

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

func _picture(parent: Control, texture: Texture2D) -> TextureRect:
    var picture := TextureRect.new()
    picture.texture = texture
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(picture)
    return picture

func _label(parent: Control, text: String, size: int, color: Color, font: Font = null, wrap: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", size)
    if font != null:
        label.add_theme_font_override("font", font)
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label
