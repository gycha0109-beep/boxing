extends VBoxContainer

signal training_requested()
signal match_requested()
signal profile_requested()
signal ranking_requested()
signal management_requested()
signal continue_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const HERO := preload("res://assets/visual/reference_v1/profile_boxer.png")
const TRAINING_ART := preload("res://assets/visual/reference_v1/training_bag.png")
const MATCH_ART := preload("res://assets/visual/v18/fight_ring_scene.webp")
const CAREER_ART := preload("res://assets/visual/reference_v1/legacy_trophy.webp")

const INK := Color("#08131f")
const PANEL := Color("#101e2c")
const PANEL_ALT := Color("#162535")
const GOLD := Color("#e9bd70")
const GOLD_DARK := Color("#94703c")
const PAPER := Color("#f7f2e8")
const MUTED := Color("#b9c4ce")
const GREEN := Color("#83d1a0")

var heading_font: Font
var bold_font: Font

func _ready() -> void:
    name = "ReferenceHome"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 9)
    _add_background()
    _intro()
    _fighter_panel()
    _objective_panel()
    _main_actions()
    _continue_panel()
    _career_strip()

func _add_background() -> void:
    var layer := CanvasLayer.new()
    layer.layer = -1
    add_child(layer)
    var background := TextureRect.new()
    background.name = "HomeStadiumBackground"
    background.texture = MATCH_ART
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.modulate = Color(1.0, 1.0, 1.0, 0.24)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.position = Vector2.ZERO
    background.size = get_viewport_rect().size
    layer.add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.055, 0.58)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.position = Vector2.ZERO
    shade.size = get_viewport_rect().size
    layer.add_child(shade)

func _intro() -> void:
    var title := _label(self, "한 명의 복서, 무한한 커리어.", 23, PAPER, heading_font)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.custom_minimum_size.y = 36
    var subtitle := _label(self, "B O X I N G   C A R E E R   R O G U E L I T E", 9, GOLD, bold_font)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var rule := ColorRect.new()
    rule.color = Color("#9e743c")
    rule.custom_minimum_size.y = 1
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rule)

func _fighter_panel() -> void:
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    var frame := _panel(self, INK, GOLD_DARK, 3)
    frame.name = "HomeFighterPanel"
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 0)
    frame.add_child(row)

    var portrait := TextureRect.new()
    portrait.name = "HomeFighterPortrait"
    portrait.texture = HERO
    portrait.custom_minimum_size = Vector2(145, 278)
    portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    info.add_theme_constant_override("margin_left", 8)
    info.add_theme_constant_override("margin_right", 5)
    info.add_theme_constant_override("margin_top", 6)
    info.add_theme_constant_override("margin_bottom", 5)
    row.add_child(info)

    _label(info, "내 복서", 12, GOLD, bold_font)
    var name_row := HBoxContainer.new()
    name_row.add_theme_constant_override("separation", 4)
    info.add_child(name_row)
    var fighter_name := _label(name_row, str(boxer.get("name", "무명 복서")), 24, PAPER, heading_font)
    fighter_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fighter_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var weight := str(GameState.career_balance.get("weight_class", {}).get("name", "웰터급"))
    _label(name_row, weight, 10, MUTED, bold_font)

    var quote := _label(info, "다시, 세계의 링을 향해.", 12, MUTED, heading_font)
    quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _rule(info)

    var stat_row := HBoxContainer.new()
    stat_row.add_theme_constant_override("separation", 6)
    info.add_child(stat_row)
    var stats := [
        {"id":"power", "label":"공격력"},
        {"id":"defense", "label":"수비력"},
        {"id":"conditioning", "label":"체력"},
        {"id":"technique", "label":"기술"},
        {"id":"speed", "label":"멘탈"},
    ]
    var total := 0
    for item in stats:
        total += int(boxer.get(str(item.id), 0))
    var overall := roundi(float(total) / float(stats.size()))
    var badge := PanelContainer.new()
    badge.custom_minimum_size = Vector2(65, 86)
    badge.add_theme_stylebox_override("panel", UI.beveled_panel_style(Color("#bd8a3d"), GOLD, 3))
    stat_row.add_child(badge)
    var badge_content := VBoxContainer.new()
    badge_content.alignment = BoxContainer.ALIGNMENT_CENTER
    badge_content.add_theme_constant_override("separation", 0)
    badge.add_child(badge_content)
    _label(badge_content, "OVR", 12, INK, bold_font).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var score := _label(badge_content, str(overall), 35, INK, heading_font)
    score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var bars := VBoxContainer.new()
    bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bars.add_theme_constant_override("separation", 3)
    stat_row.add_child(bars)
    for item in stats:
        _stat_bar(bars, str(item.label), int(boxer.get(str(item.id), 0)))
    _rule(info)
    _record_row(info, career)

func _record_row(parent: VBoxContainer, career: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 3)
    parent.add_child(row)
    _metric(row, "전적", "%d승 %d패 %d무" % [
        int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0))
    ])
    _metric(row, "랭킹", "#%d" % int(career.get("rank", 50)))
    _metric(row, "커리어 단계", GameState.tier_label())

func _metric(parent: HBoxContainer, caption: String, value: String) -> void:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 1)
    parent.add_child(box)
    _label(box, caption, 9, GOLD, bold_font)
    var data := _label(box, value, 11, PAPER, bold_font)
    data.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _stat_bar(parent: VBoxContainer, caption: String, value: int) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    parent.add_child(row)
    var label := _label(row, caption, 10, PAPER, bold_font)
    label.custom_minimum_size.x = 42
    var bar := ProgressBar.new()
    bar.name = "HomeStat_" + caption
    bar.min_value = 0
    bar.max_value = 100
    bar.value = clampi(value, 0, 100)
    bar.show_percentage = false
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.custom_minimum_size.y = 7
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_theme_stylebox_override("background", UI.panel_style(Color("#26313d"), Color("#34414d"), 0))
    bar.add_theme_stylebox_override("fill", UI.panel_style(GOLD, GOLD, 0))
    row.add_child(bar)
    var amount := _label(row, str(value), 10, PAPER, bold_font)
    amount.custom_minimum_size.x = 22
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _objective_panel() -> void:
    var career: Dictionary = GameState.state.get("career", {})
    var headline := "프로 데뷔 준비" if int(career.get("fights", 0)) == 0 else "랭킹전 출전"
    if bool(career.get("champion", false)):
        headline = "타이틀 방어"
    var outer := Control.new()
    outer.name = "HomeCurrentObjective"
    outer.custom_minimum_size.y = 90
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(outer)
    var frame := _panel(outer, PANEL, GOLD_DARK, 3)
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    frame.add_child(row)
    var art := TextureRect.new()
    art.texture = MATCH_ART
    art.custom_minimum_size = Vector2(105, 76)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(art)
    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.alignment = BoxContainer.ALIGNMENT_CENTER
    copy.add_theme_constant_override("separation", 2)
    row.add_child(copy)
    _label(copy, "현재 목표", 11, GOLD, bold_font)
    _label(copy, headline, 21, PAPER, heading_font)
    var detail := _label(copy, "상위 랭커와의 경기로 타이틀 도전권을 노리세요.", 11, MUTED)
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var arrow := _label(row, "›", 28, GOLD, heading_font)
    arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    arrow.custom_minimum_size.x = 15
    var click := _click_overlay(outer, "HomeObjectiveAction")
    click.pressed.connect(func(): match_requested.emit())

func _main_actions() -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 7)
    add_child(row)
    _action_card(row, TRAINING_ART, "훈련", "능력을 강화하고\n컨디션을 끌어올리세요.", "HomeTrainingAction", func(): training_requested.emit())
    _action_card(row, MATCH_ART, "경기", "다음 경기에 출전해\n커리어를 이어가세요.", "HomeMatchAction", func(): match_requested.emit())
    _action_card(row, CAREER_ART, "커리어", "전적과 랭킹, 타이틀을\n관리하세요.", "HomeCareerAction", func(): ranking_requested.emit())

func _action_card(parent: HBoxContainer, art: Texture2D, title: String, description: String, node_name: String, callback: Callable) -> void:
    var outer := Control.new()
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.custom_minimum_size = Vector2(0, 160)
    parent.add_child(outer)
    var frame := _panel(outer, PANEL, GOLD_DARK, 4)
    frame.name = node_name + "Frame"
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 2)
    frame.add_child(content)
    var photo := TextureRect.new()
    photo.texture = art
    photo.custom_minimum_size.y = 84
    photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(photo)
    var label := _label(content, title, 17, PAPER, heading_font)
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    var copy := _label(content, description, 10, MUTED, bold_font)
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.max_lines_visible = 2
    var click := _click_overlay(outer, node_name)
    click.pressed.connect(callback)

func _continue_panel() -> void:
    var button := UI.action_button("▶  커리어 이어하기", heading_font, true)
    button.name = "HomeContinueCareer"
    button.custom_minimum_size.y = 68
    button.add_theme_font_size_override("font_size", 23)
    button.add_theme_stylebox_override("normal", UI.gold_button_style())
    button.add_theme_stylebox_override("hover", UI.gold_button_style())
    button.pressed.connect(func(): continue_requested.emit())
    add_child(button)

func _career_strip() -> void:
    var career: Dictionary = GameState.state.get("career", {})
    var fights := int(career.get("fights", 0))
    var season := 1 + int(fights / 4)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 9)
    add_child(row)
    _label(row, "시즌 %d" % season, 11, MUTED, bold_font)
    _label(row, "│", 10, GOLD_DARK)
    _label(row, GameState.tier_label(), 11, GOLD, bold_font)
    _label(row, "│", 10, GOLD_DARK)
    _label(row, "%d승 %d패" % [int(career.get("wins", 0)), int(career.get("losses", 0))], 11, MUTED, bold_font)

func _panel(parent: Control, background: Color, edge: Color, padding: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(background, edge, padding))
    parent.add_child(panel)
    return panel

func _click_overlay(parent: Control, node_name: String) -> Button:
    var button := Button.new()
    button.name = node_name
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        button.add_theme_stylebox_override(state, empty)
    button.add_theme_color_override("font_color", Color.TRANSPARENT)
    button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(button)
    return button

func _label(parent: Control, copy: String, points: int, tint: Color, font: Font = null) -> Label:
    var label := Label.new()
    label.text = copy
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", tint)
    if font != null:
        label.add_theme_font_override("font", font)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label

func _rule(parent: Control) -> void:
    var line := ColorRect.new()
    line.color = Color("#92703e")
    line.custom_minimum_size.y = 1
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(line)
