extends RefCounted
## Shared visual finishing for existing Twelve Count screens.
## This refines controls in-place without changing their hierarchy or gameplay.

const INK := Color("#0c121b")
const PANEL := Color("#151e28")
const PANEL_RAISED := Color("#1c2732")
const GOLD := Color("#d7ae63")
const GOLD_LIGHT := Color("#f5d590")
const TEXT := Color("#f3eee5")
const MUTED := Color("#b9c0c8")
const BORDER := Color("#46515e")
const POSITIVE := Color("#7dd2a4")
const NEGATIVE := Color("#ef8b84")
const BODY_FONT := preload("res://assets/fonts/NotoSansKR-VF.ttf")

static func theme_for_game() -> Theme:
    var theme := Theme.new()
    theme.default_font = BODY_FONT
    theme.default_font_size = 13
    theme.set_color("font_color", "Label", TEXT)
    theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.28))
    theme.set_color("font_color", "Button", TEXT)
    theme.set_color("font_hover_color", "Button", GOLD_LIGHT)
    theme.set_color("font_pressed_color", "Button", INK)
    theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
    theme.set_font_size("font_size", "Button", 14)
    theme.set_font_size("font_size", "Label", 13)
    theme.set_stylebox("normal", "Button", _plate(PANEL, BORDER, 8, 10))
    theme.set_stylebox("hover", "Button", _plate(PANEL_RAISED, GOLD, 8, 10))
    theme.set_stylebox("pressed", "Button", _plate(GOLD, GOLD_LIGHT, 8, 10))
    theme.set_stylebox("disabled", "Button", _plate(INK, BORDER.darkened(0.2), 8, 10))
    theme.set_stylebox("focus", "Button", _outline(GOLD_LIGHT))
    theme.set_stylebox("panel", "PanelContainer", _plate(PANEL, BORDER, 9, 10))
    theme.set_color("font_color", "CheckButton", TEXT)
    theme.set_color("font_hover_color", "CheckButton", GOLD_LIGHT)
    theme.set_color("font_color", "OptionButton", TEXT)
    theme.set_stylebox("normal", "OptionButton", _plate(PANEL, BORDER, 8, 8))
    theme.set_stylebox("hover", "OptionButton", _plate(PANEL_RAISED, GOLD, 8, 8))
    theme.set_stylebox("focus", "OptionButton", _outline(GOLD_LIGHT))
    theme.set_color("font_color", "LineEdit", TEXT)
    theme.set_color("font_placeholder_color", "LineEdit", MUTED)
    theme.set_stylebox("normal", "LineEdit", _plate(INK, BORDER, 7, 9))
    theme.set_stylebox("focus", "LineEdit", _plate(INK, GOLD, 7, 9))
    theme.set_stylebox("background", "ProgressBar", _plate(Color("#091019"), Color("#2b3642"), 4, 1))
    theme.set_stylebox("fill", "ProgressBar", _plate(GOLD, GOLD_LIGHT, 4, 0))
    return theme

static func polish_tree(node: Node) -> void:
    if node is Control and node.name == &"ReferenceTitle":
        return
    if node is Control:
        _polish_control(node as Control)
    for child in node.get_children():
        polish_tree(child)

static func _polish_control(control: Control) -> void:
    if control.has_meta(&"twelve_polished"):
        return
    control.set_meta(&"twelve_polished", true)
    if control is ScrollContainer:
        (control as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    if control is Label:
        var label := control as Label
        if label.has_theme_font_size_override("font_size"):
            var sz := label.get_theme_font_size("font_size")
            if sz == 10 and not _is_navigation(label):
                label.add_theme_font_size_override("font_size", 11)
        if label.has_theme_color_override("font_color"):
            var color := label.get_theme_color("font_color")
            if color.r < 0.72 and color.g < 0.72 and color.b < 0.72 and not _is_navigation(label):
                label.add_theme_color_override("font_color", color.lerp(TEXT, 0.18))
    if control is Button:
        var button := control as Button
        if button.flat:
            return
        if button.has_theme_stylebox_override("normal"):
            var normal := button.get_theme_stylebox("normal")
            if normal is StyleBoxFlat:
                var box := normal as StyleBoxFlat
                var hover := box.duplicate() as StyleBoxFlat
                hover.border_color = GOLD_LIGHT
                hover.bg_color = box.bg_color.lightened(0.11)
                if not button.has_theme_stylebox_override("hover"):
                    button.add_theme_stylebox_override("hover", hover)
                if not button.has_theme_stylebox_override("focus"):
                    button.add_theme_stylebox_override("focus", _outline(GOLD_LIGHT))
                if not button.has_theme_color_override("font_hover_color"):
                    button.add_theme_color_override("font_hover_color", button.get_theme_color("font_color"))
        if button.custom_minimum_size.y > 0 and button.custom_minimum_size.y < 40 and not _is_navigation(button):
            button.custom_minimum_size.y = 40
    if control is PanelContainer:
        var container := control as PanelContainer
        if container.has_theme_stylebox_override("panel"):
            var style := container.get_theme_stylebox("panel")
            if style is StyleBoxFlat:
                var clone := style.duplicate() as StyleBoxFlat
                var is_gold := clone.border_color.r > 0.45 and clone.border_color.g > 0.30 and clone.border_color.b < 0.60
                if not is_gold:
                    clone.border_color = clone.border_color.lerp(BORDER, 0.4)
                clone.shadow_color = Color(0, 0, 0, 0.27)
                clone.shadow_size = 2
                container.add_theme_stylebox_override("panel", clone)

static func _is_navigation(c: Control) -> bool:
    var n: Node = c
    for i in range(5):
        if n == null:
            break
        if str(n.name).contains("BottomNav") or str(n.name).contains("NavButton"):
            return true
        n = n.get_parent()
    return false

static func _plate(bg: Color, edge: Color, radius: int, pad: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = edge
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(pad)
    return s

static func _outline(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color.TRANSPARENT
    s.border_color = color
    s.set_border_width_all(2)
    s.set_corner_radius_all(8)
    return s
