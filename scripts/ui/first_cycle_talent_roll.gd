extends VBoxContainer

signal reveal_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const GOLD := Color("#efbc68")
const WHITE := Color("#f5eee2")
const MUTED := Color("#bfc8d3")

var talents: Array = []
var chosen_id := ""
var bold_font: Font
var heading_font: Font
var _names: Array[String] = []
var _result_name := ""
var _display: Label
var _description: Label
var _button: Button
var _elapsed := 0.0
var _next_tick := 0.0
var _tick := 0
var _finished := false


func _ready() -> void:
    name = "FirstCycleTalentRoll"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 10)
    for item in talents:
        var name_value := str(item.get("name", ""))
        if not name_value.is_empty():
            _names.append(name_value)
        if str(item.get("id", "")) == chosen_id:
            _result_name = name_value
    if _result_name.is_empty():
        _result_name = "타고난 재능"

    var banner := _frame(self)
    var tag := _label(banner, "NATURAL TALENT   ·   2 / 2", 19, GOLD, heading_font)
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var subtitle := _label(banner, "타고난 재능 추첨", 24, WHITE, heading_font)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var reveal := _frame(self)
    var photo := TextureRect.new()
    photo.texture = RING
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.custom_minimum_size.y = 170
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    reveal.add_child(photo)
    _display = _label(reveal, "???", 34, GOLD, heading_font)
    _display.name = "RandomTalentName"
    _display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var explanation := _frame(self)
    _description = _label(explanation, "복서의 재능은 무작위로 결정됩니다.\n추첨 결과는 선수의 커리어에 적용됩니다.", 13, WHITE, bold_font)
    _description.name = "RandomTalentDescription"
    _description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    _button = UI.action_button("재능 결정 중…", heading_font, true)
    _button.name = "RandomTalentContinue"
    _button.custom_minimum_size.y = 58
    _button.disabled = true
    _button.pressed.connect(func(): reveal_requested.emit())
    add_child(_button)
    set_process(true)


func _process(delta: float) -> void:
    if _finished:
        return
    _elapsed += delta
    if _elapsed >= _next_tick and _elapsed < 2.3:
        if not _names.is_empty():
            _display.text = _names[_tick % _names.size()]
        _tick += 1
        _next_tick += lerpf(0.075, 0.24, minf(_elapsed / 2.3, 1.0))
    if _elapsed >= 2.3:
        _finished = true
        _display.text = _result_name
        _description.text = "결과 확정! 이 재능은 선수 생성 시 결정된 값이며 재추첨되지 않습니다.\n효과와 능력치 보정을 확인해 보세요."
        _button.disabled = false
        _button.text = "재능 결과 확인  ›"
        set_process(false)


func _frame(parent: Container) -> VBoxContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", UI.beveled_panel_style(Color("#111c29"), UI.GOLD_DARK, 9))
    parent.add_child(frame)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 8)
    frame.add_child(contents)
    return contents


func _label(parent: Container, caption: String, size: int, color: Color, font: Font = null) -> Label:
    var text := Label.new()
    text.text = caption
    text.add_theme_font_size_override("font_size", size)
    text.add_theme_color_override("font_color", color)
    if font != null:
        text.add_theme_font_override("font", font)
    parent.add_child(text)
    return text
