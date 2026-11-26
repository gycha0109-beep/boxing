extends VBoxContainer

signal reveal_requested()
signal tutorial_skipped()

const UI := preload("res://scripts/ui/reference_ui.gd")
const GOLD := Color("#efbc68")
const WHITE := Color("#f5eee2")
const MUTED := Color("#aeb8c5")
const CARD_W := 118.0
const CARD_H := 136.0
const CARD_GAP := 8.0
const STEP := CARD_W + CARD_GAP
const STOP_INDEX := 27
# Keep cards beyond the winning card so the reel never exposes its terminal edge.
const TRAILING_CARDS := 8
const SPIN_DURATION := 4.6

var talents: Array = []
var chosen_id := ""
var bold_font: Font
var heading_font: Font
var _cards: Array = []
var _chosen_card: PanelContainer
var _strip: HBoxContainer
var _reel: Control
var _focus: Panel
var _status: Label
var _result_icon: TextureRect
var _result_name: Label
var _result_description: Label
var _result_bonus: Label
var _button: Button
var _elapsed := 0.0
var _start_x := 0.0
var _target_x := 0.0
var _ready_to_reveal := false
var _layout_ready := false
var _chosen: Dictionary = {}


func _ready() -> void:
    name = "FirstCycleTalentRoll"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 10)
    _build_view()
    call_deferred("_prepare_reel")


func _build_view() -> void:
    var banner := _panel(self)
    var step := _label(banner, "NATURAL TALENT  ·  2 / 10", 13, GOLD, heading_font, HORIZONTAL_ALIGNMENT_CENTER)
    step.name = "TutorialStepTitle"
    _label(banner, "타고난 재능 추첨", 25, WHITE, heading_font, HORIZONTAL_ALIGNMENT_CENTER)
    _label(banner, "복서에게 주어질 고유한 재능을 결정합니다.", 12, MUTED, bold_font, HORIZONTAL_ALIGNMENT_CENTER)

    var reel_panel := _panel(self)
    _label(reel_panel, "TALENT ROULETTE", 11, GOLD, heading_font, HORIZONTAL_ALIGNMENT_CENTER)
    _reel = Control.new()
    _reel.name = "TalentRouletteViewport"
    _reel.custom_minimum_size = Vector2(0, 158)
    _reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _reel.clip_contents = true
    reel_panel.add_child(_reel)

    _strip = HBoxContainer.new()
    _strip.name = "TalentRouletteStrip"
    _strip.add_theme_constant_override("separation", int(CARD_GAP))
    _strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _reel.add_child(_strip)

    _focus = Panel.new()
    _focus.name = "TalentRouletteFocus"
    _focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var focus_style := StyleBoxFlat.new()
    focus_style.bg_color = Color(0.12, 0.09, 0.035, 0.12)
    focus_style.border_color = GOLD
    focus_style.set_border_width_all(3)
    focus_style.set_corner_radius_all(8)
    focus_style.shadow_color = Color(1.0, 0.62, 0.12, 0.45)
    focus_style.shadow_size = 12
    _focus.add_theme_stylebox_override("panel", focus_style)
    _reel.add_child(_focus)

    _status = _label(reel_panel, "재능 카드가 룰렛에 들어갑니다…", 13, GOLD, bold_font, HORIZONTAL_ALIGNMENT_CENTER)
    _status.name = "TalentRouletteStatus"

    var result_panel := _panel(self)
    var result_row := HBoxContainer.new()
    result_row.add_theme_constant_override("separation", 12)
    result_panel.add_child(result_row)
    _result_icon = TextureRect.new()
    _result_icon.name = "TalentResultIcon"
    _result_icon.custom_minimum_size = Vector2(68, 68)
    _result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    result_row.add_child(_result_icon)
    var result_copy := VBoxContainer.new()
    result_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result_copy.add_theme_constant_override("separation", 4)
    result_row.add_child(result_copy)
    _result_name = _label(result_copy, "???", 20, WHITE, heading_font)
    _result_name.name = "TalentResultName"
    _result_description = _label(result_copy, "룰렛이 멈추면 타고난 재능이 공개됩니다.", 12, MUTED, bold_font)
    _result_description.name = "TalentResultDescription"
    _result_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _result_bonus = _label(result_copy, "", 12, GOLD, bold_font)
    _result_bonus.name = "TalentResultBonus"

    _button = UI.action_button("재능 추첨 중…", heading_font, true)
    _button.name = "RandomTalentContinue"
    _button.custom_minimum_size.y = 58
    _button.disabled = true
    _button.pressed.connect(func(): reveal_requested.emit())
    add_child(_button)

    var skip := Button.new()
    skip.name = "TutorialSkip"
    skip.text = "튜토리얼 건너뛰기"
    skip.flat = true
    skip.custom_minimum_size.y = 36
    skip.pressed.connect(func(): tutorial_skipped.emit())
    add_child(skip)


func _prepare_reel() -> void:
    for item in talents:
        if str(item.get("id", "")) == chosen_id:
            _chosen = item.duplicate(true)
            break
    if _chosen.is_empty():
        _status.text = "재능 데이터를 불러오지 못했습니다."
        return
    if talents.is_empty():
        return

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    # Put every real talent on the reel at least once, in shuffled order.
    var opening_set: Array = talents.duplicate()
    opening_set.shuffle()
    for item in opening_set:
        _add_talent_card(item)
    for i in range(opening_set.size(), STOP_INDEX):
        var item: Dictionary = talents[rng.randi_range(0, talents.size() - 1)]
        _add_talent_card(item)
    _add_talent_card(_chosen)

    # The winning card is the stopping point, not the end of the strip.
    # Add a shuffled-looking tail after it so the viewport remains visually continuous.
    var trailing_options: Array = []
    for item in talents:
        if str(item.get("id", "")) != chosen_id:
            trailing_options.append(item)
    for i in range(TRAILING_CARDS):
        var tail_item: Dictionary = _chosen
        if not trailing_options.is_empty():
            tail_item = trailing_options[rng.randi_range(0, trailing_options.size() - 1)]
        _add_talent_card(tail_item)

    var total_cards := STOP_INDEX + 1 + TRAILING_CARDS
    _strip.size = Vector2(float(total_cards) * CARD_W + float(total_cards - 1) * CARD_GAP, CARD_H)
    var layout_frames := 0
    while _reel.size.x <= 0.0 and layout_frames < 8:
        await get_tree().process_frame
        layout_frames += 1
    _layout_reel()
    if _reel.size.x <= 0.0:
        _status.text = "룰렛 화면을 준비하지 못했습니다."
        _finish_roll()
        return
    _layout_ready = true
    set_process(true)


func _add_talent_card(item: Dictionary) -> void:
    var card := PanelContainer.new()
    card.set_meta("talent_id", str(item.get("id", "")))
    card.custom_minimum_size = Vector2(CARD_W, CARD_H)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#172331")
    style.border_color = Color("#586575")
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    card.add_theme_stylebox_override("panel", style)
    _strip.add_child(card)

    var content := VBoxContainer.new()
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 5)
    card.add_child(content)
    var icon := TextureRect.new()
    icon.texture = _talent_icon(str(item.get("id", "")))
    icon.custom_minimum_size = Vector2(54, 54)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    content.add_child(icon)
    var title := _label(content, str(item.get("name", "재능")), 14, WHITE, heading_font, HORIZONTAL_ALIGNMENT_CENTER)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var hint := _label(content, _short_description(str(item.get("id", ""))), 9, MUTED, bold_font, HORIZONTAL_ALIGNMENT_CENTER)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _cards.append(card)
    if str(item.get("id", "")) == chosen_id:
        _chosen_card = card


func _process(delta: float) -> void:
    if not _layout_ready or _ready_to_reveal:
        return
    _elapsed += delta
    var progress := clampf(_elapsed / SPIN_DURATION, 0.0, 1.0)
    var eased := 1.0 - pow(1.0 - progress, 4.0)
    _strip.position.x = lerpf(_start_x, _target_x, eased)
    if progress < 0.22:
        _status.text = "재능 카드 확인 중…"
    elif progress < 0.78:
        _status.text = "타고난 재능을 추첨하고 있습니다…"
    elif progress < 1.0:
        _status.text = "추첨 결과를 확정합니다…"
    else:
        _strip.position.x = _target_x
        _finish_roll()
        set_process(false)


func _finish_roll() -> void:
    if _ready_to_reveal:
        return
    _ready_to_reveal = true
    if is_instance_valid(_chosen_card):
        var highlight := StyleBoxFlat.new()
        highlight.bg_color = Color("#2b2418")
        highlight.border_color = GOLD
        highlight.set_border_width_all(3)
        highlight.set_corner_radius_all(7)
        highlight.shadow_color = Color(1.0, 0.62, 0.12, 0.58)
        highlight.shadow_size = 16
        _chosen_card.add_theme_stylebox_override("panel", highlight)
        _chosen_card.pivot_offset = _chosen_card.size * 0.5
        var reveal_tween := create_tween()
        reveal_tween.tween_property(_chosen_card, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        reveal_tween.tween_property(_chosen_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
    _result_icon.texture = _talent_icon(chosen_id)
    _result_name.text = str(_chosen.get("name", "타고난 재능"))
    _result_description.text = str(_chosen.get("description", ""))
    _result_bonus.text = _format_bonus(_chosen.get("stat_bonus", {}))
    _status.text = "추첨 완료  ·  실제 배정된 재능에 멈췄습니다"
    _button.disabled = false
    _button.text = "결과 확인  ›"


func _layout_reel() -> void:
    var width := _reel.size.x
    if width <= 0.0:
        return
    _start_x = (width - CARD_W) * 0.5
    _target_x = _start_x - float(STOP_INDEX) * STEP
    _strip.position = Vector2(_start_x, 10)
    _focus.position = Vector2((width - CARD_W) * 0.5, 7)
    _focus.size = Vector2(CARD_W, CARD_H + 6)


func _panel(parent: Container) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(Color("#111c29"), UI.GOLD_DARK, 8))
    parent.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 6)
    panel.add_child(content)
    return content


func _label(parent: Container, value: String, size: int, color: Color, font: Font, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = alignment
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if font != null:
        label.add_theme_font_override("font", font)
    parent.add_child(label)
    return label


func _short_description(id: String) -> String:
    match id:
        "iron_chin": return "맷집 특화"
        "glass_cannon": return "강한 한 방"
        "workhorse": return "훈련 효율"
        "technician": return "정교한 기술"
        "crowd_favorite": return "흥행 보너스"
        "quick_healer": return "빠른 회복"
        _: return "고유한 재능"


func _format_bonus(bonuses: Dictionary) -> String:
    var labels := {"power":"파워", "speed":"스피드", "technique":"테크닉", "defense":"수비", "conditioning":"체력"}
    var parts: Array[String] = []
    for key in labels:
        var value := int(bonuses.get(key, 0))
        if value != 0:
            parts.append("%s %s%d" % [labels[key], "+" if value > 0 else "", value])
    return " · ".join(parts) if not parts.is_empty() else "특수 효과 적용"


func _talent_icon(id: String) -> Texture2D:
    var gold := "#f0c879"
    var pale := "#fff0c9"
    var drawing := ""
    match id:
        "iron_chin":
            drawing = '<path d="M32 5L53 13V29C53 43 43 54 32 60C21 54 11 43 11 29V13Z" fill="none" stroke="%s" stroke-width="4"/><path d="M19 31L28 40L46 22" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>' % [gold, pale]
        "glass_cannon":
            drawing = '<path d="M32 5L56 25L43 56L22 52L8 26Z" fill="none" stroke="%s" stroke-width="4"/><path d="M32 5L29 28L43 56M29 28L8 26M29 28L49 22" fill="none" stroke="%s" stroke-width="3"/>' % [gold, pale]
        "workhorse":
            drawing = '<path d="M7 22H18V42H7ZM46 22H57V42H46ZM18 28H46V36H18Z" fill="none" stroke="%s" stroke-width="4"/><path d="M32 14V50" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % [gold, pale]
        "technician":
            drawing = '<circle cx="32" cy="32" r="24" fill="none" stroke="%s" stroke-width="4"/><circle cx="32" cy="32" r="12" fill="none" stroke="%s" stroke-width="3"/><path d="M32 3V19M32 45V61M3 32H19M45 32H61" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % [gold, pale, gold]
        "crowd_favorite":
            drawing = '<path d="M32 7L39 23L57 25L44 38L47 56L32 47L17 56L20 38L7 25L25 23Z" fill="none" stroke="%s" stroke-width="4" stroke-linejoin="round"/><circle cx="32" cy="32" r="5" fill="%s"/>' % [gold, pale]
        "quick_healer":
            drawing = '<path d="M32 56S7 42 7 23C7 8 27 5 32 20C37 5 57 8 57 23C57 42 32 56 32 56Z" fill="none" stroke="%s" stroke-width="4"/><path d="M13 32H25L31 21L38 42L44 32H53" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [gold, pale]
        _:
            drawing = '<circle cx="32" cy="32" r="24" fill="none" stroke="%s" stroke-width="4"/><path d="M20 32H44M32 20V44" stroke="%s" stroke-width="4"/>' % [gold, pale]
    var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="#172536" stroke="#8b693d" stroke-width="1.5"/>%s</svg>' % drawing
    var image := Image.new()
    if image.load_svg_from_string(svg) != OK:
        return null
    return ImageTexture.create_from_image(image)
