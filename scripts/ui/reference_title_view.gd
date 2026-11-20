extends VBoxContainer

signal new_career_requested()
signal continue_requested()

const UI := preload("res://scripts/ui/reference_ui.gd")
const Art := preload("res://scripts/ui/reference_result_art.gd")
const TITLE_METAL := preload("res://scripts/ui/reference_title_type.gdshader")
const RING := preload("res://assets/visual/reference_v1/title_ring.webp")
const BOXER := preload("res://assets/visual/reference_v1/title_boxer.webp")
const TACTICS := preload("res://assets/visual/reference_v1/title_tactics.webp")
const LEGACY := preload("res://assets/visual/reference_v1/title_legacy.webp")
const INK := Color("#080e15")
const PAPER := Color("#f7f3e9")
const MUTED := Color("#c7ccd2")
const EDGE := Color("#bc8e4d")

var heading_font: Font
var bold_font: Font
var can_continue := false
var save_caption := ""

var _confirmation: ConfirmationDialog
var _leaving := false

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 8)
    _hero()
    _features()
    _actions()
    if can_continue:
        _make_confirmation()

func _hero() -> void:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", UI.beveled_panel_style(INK, Color("#6c542f"), 1))
    add_child(frame)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 0)
    frame.add_child(content)

    var masthead := VBoxContainer.new()
    masthead.add_theme_constant_override("separation", 0)
    content.add_child(masthead)
    var heading := HBoxContainer.new()
    heading.alignment = BoxContainer.ALIGNMENT_CENTER
    heading.add_theme_constant_override("separation", 5)
    masthead.add_child(heading)
    Art.laurel(heading, 39, UI.GOLD, false)
    var title := _label(heading, "TWELVE COUNT", 53, PAPER, UI.DISPLAY_FONT)
    _outline(title, 5)
    var title_material := ShaderMaterial.new()
    title_material.shader = TITLE_METAL
    title.material = title_material
    title_material.set_shader_parameter("label_height", title.get_minimum_size().y)
    title.resized.connect(func(): title_material.set_shader_parameter("label_height", title.size.y))
    Art.laurel(heading, 39, UI.GOLD, true)
    var subtitle := _label(masthead, "B O X I N G   C A R E E R   R O G U E L I T E", 11, MUTED, bold_font)
    subtitle.custom_minimum_size.y = 23
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _rule(content)

    var scene := Control.new()
    scene.custom_minimum_size.y = 249
    scene.clip_contents = true
    scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(scene)
    var photo := _texture(scene, RING)
    photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _bottom_shadow(scene)
    Art.glow(scene, Vector2(0.5, 0.015), Vector2(295, 12), Color(1.0, 0.77, 0.40, 0.83))

    var tagline := VBoxContainer.new()
    tagline.add_theme_constant_override("separation", 0)
    content.add_child(tagline)
    _label(tagline, "단 한 명의 복서, 단 한 번의 커리어.", 17, PAPER, heading_font)
    var highlighted := HBoxContainer.new()
    highlighted.alignment = BoxContainer.ALIGNMENT_CENTER
    highlighted.add_theme_constant_override("separation", 3)
    tagline.add_child(highlighted)
    _label(highlighted, "그리고 이어지는", 18, PAPER, heading_font)
    _label(highlighted, "유산과 새로운 시작.", 18, UI.GOLD_BRIGHT, heading_font)
    var padding := Control.new()
    padding.custom_minimum_size.y = 6
    padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tagline.add_child(padding)
    _rule(content)

func _features() -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    add_child(row)
    _feature(row, BOXER, "한 명의 복서", "훈련하고 챔피언에 도전")
    _feature(row, TACTICS, "전술 준비", "상대에 맞춰 전략 선택")
    _feature(row, LEGACY, "유산 계승", "다음 제자에게 노하우 전수")

func _feature(row: HBoxContainer, art: Texture2D, title: String, caption: String) -> void:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", UI.beveled_panel_style(Color("#121922"), EDGE, 5))
    row.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 2)
    panel.add_child(content)
    var graphic := _texture(content, art)
    graphic.custom_minimum_size.y = 59
    _label(content, title, 16, PAPER, heading_font)
    _rule(content)
    var detail := _label(content, caption, 11, MUTED, bold_font)
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.custom_minimum_size.y = 26

func _actions() -> void:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    add_child(box)
    var stage := CenterContainer.new()
    stage.custom_minimum_size.y = 71
    box.add_child(stage)

    var light := Control.new()
    light.mouse_filter = Control.MOUSE_FILTER_IGNORE
    light.custom_minimum_size = Vector2(382, 71)
    stage.add_child(light)
    Art.glow(light, Vector2(0.5, 0.095), Vector2(344, 27), Color(1.0, 0.61, 0.24, 0.86))
    Art.glow(light, Vector2(0.5, 0.905), Vector2(350, 29), Color(1.0, 0.56, 0.21, 0.76))

    var start := UI.action_button("새 커리어 시작", heading_font, true)
    start.name = "TitleNewCareer"
    start.custom_minimum_size = Vector2(352, 60)
    start.add_theme_font_size_override("font_size", 25)
    start.add_theme_stylebox_override("normal", Art.gold_plate(352, 60, Color("#cb913d"), 4))
    start.add_theme_stylebox_override("hover", Art.gold_plate(352, 60, Color("#e2ac56"), 4))
    start.add_theme_stylebox_override("pressed", Art.gold_plate(352, 60, Color("#a66c2d"), 4))
    start.pressed.connect(_request_new_career)
    stage.add_child(start)

    var resume := UI.action_button("이어하기", heading_font)
    resume.name = "TitleContinue"
    resume.disabled = not can_continue
    resume.custom_minimum_size = Vector2(230, 48)
    resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    resume.add_theme_font_size_override("font_size", 18)
    resume.add_theme_stylebox_override("normal", UI.beveled_panel_style(Color("#151c24"), EDGE, 5))
    resume.add_theme_stylebox_override("hover", UI.beveled_panel_style(Color("#202c38"), UI.GOLD_BRIGHT, 5))
    resume.add_theme_stylebox_override("pressed", UI.beveled_panel_style(Color("#10161b"), EDGE, 5))
    resume.add_theme_stylebox_override("disabled", UI.beveled_panel_style(Color("#14181c"), Color("#6c593e"), 5))
    resume.pressed.connect(func():
        if not _leaving and can_continue:
            _leaving = true
            continue_requested.emit()
    )
    box.add_child(resume)
    if not save_caption.is_empty():
        _label(box, save_caption, 11, MUTED, bold_font).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    elif not can_continue:
        _label(box, "저장된 커리어가 없습니다", 11, MUTED, bold_font)

func _make_confirmation() -> void:
    _confirmation = ConfirmationDialog.new()
    _confirmation.name = "TitleConfirmOverwrite"
    _confirmation.title = "새 커리어 시작"
    _confirmation.dialog_text = "저장된 선수의 진행과 체육관 유산을 덮어씁니다.\n새 커리어를 시작할까요?"
    _confirmation.dialog_autowrap = true
    _confirmation.ok_button_text = "새로 시작"
    _confirmation.cancel_button_text = "취소"
    var dialog_theme := Theme.new()
    dialog_theme.default_font = bold_font
    dialog_theme.default_font_size = 14
    dialog_theme.set_color("title_color", "Window", UI.GOLD_BRIGHT)
    for style_name in ["embedded_border", "embedded_unfocused_border"]:
        var border := ThemeDB.get_default_theme().get_stylebox(style_name, "Window").duplicate() as StyleBoxFlat
        border.bg_color = Color("#141c26")
        border.border_color = EDGE
        dialog_theme.set_stylebox(style_name, "Window", border)
    dialog_theme.set_stylebox("panel", "AcceptDialog", UI.panel_style(INK, EDGE, 13))
    _confirmation.theme = dialog_theme
    add_child(_confirmation)
    var accept := _confirmation.get_ok_button()
    accept.add_theme_stylebox_override("normal", _dialog_button_style(Art.gold_plate(112, 44, Color("#b98137"), 2), 23))
    accept.add_theme_stylebox_override("hover", _dialog_button_style(Art.gold_plate(112, 44, Color("#dba748"), 2), 23))
    accept.add_theme_stylebox_override("pressed", _dialog_button_style(Art.gold_plate(112, 44, Color("#9a642c"), 2), 23))
    for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        accept.add_theme_color_override(state, INK)
    var cancel := _confirmation.get_cancel_button()
    cancel.add_theme_stylebox_override("normal", _dialog_button_style(UI.beveled_panel_style(Color("#222c37"), EDGE, 5), 32))
    cancel.add_theme_stylebox_override("hover", _dialog_button_style(UI.beveled_panel_style(Color("#2b3845"), UI.GOLD_BRIGHT, 5), 32))
    _confirmation.confirmed.connect(_begin_new_career, CONNECT_DEFERRED)

func _dialog_button_style(style: StyleBox, horizontal: int) -> StyleBox:
    var padded := style.duplicate() as StyleBox
    padded.set_content_margin(SIDE_LEFT, horizontal)
    padded.set_content_margin(SIDE_RIGHT, horizontal)
    padded.set_content_margin(SIDE_TOP, 14)
    padded.set_content_margin(SIDE_BOTTOM, 14)
    return padded


func _request_new_career() -> void:
    if _leaving:
        return
    if can_continue:
        _confirmation.popup_centered(Vector2i(323, 0))
        _confirmation.get_cancel_button().grab_focus()
    else:
        _begin_new_career()

func _begin_new_career() -> void:
    if not _leaving:
        _leaving = true
        new_career_requested.emit()

func _bottom_shadow(parent: Control) -> void:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.73, 1.0])
    gradient.colors = PackedColorArray([Color(INK, 0), Color(INK, 0), INK])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 2
    texture.height = 128
    texture.fill_to = Vector2(0, 1)
    var shadow := _texture(parent, texture)
    shadow.stretch_mode = TextureRect.STRETCH_SCALE
    shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _texture(parent: Control, image: Texture2D) -> TextureRect:
    var graphic := TextureRect.new()
    graphic.texture = image
    graphic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    graphic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(graphic)
    return graphic

func _rule(parent: Control) -> void:
    var rule := ColorRect.new()
    rule.color = Color("#9e743c8a")
    rule.custom_minimum_size.y = 1
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(rule)

func _outline(label: Label, amount: int) -> void:
    label.add_theme_constant_override("outline_size", amount)
    label.add_theme_color_override("font_outline_color", INK)

func _label(parent: Control, text: String, size: int, tint: Color, font: Font) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_override("font", font)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", tint)
    parent.add_child(label)
    return label
