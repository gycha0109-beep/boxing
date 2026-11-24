extends RefCounted

const DIFFICULTY := {"safe": "낮음", "peer": "보통", "stretch": "높음"}
const GOLD := Color("#efc46f")
const GOLD_BRIGHT := Color("#ffe2a0")
const GOLD_DARK := Color("#ae8246")
const DISPLAY_FONT := preload("res://assets/fonts/BarlowCondensed-BlackItalic.ttf")

static var _gold_style: StyleBoxTexture
static var _beveled_styles: Dictionary = {}

static func gold_button_style() -> StyleBoxTexture:
    if _gold_style != null:
        return _gold_style

    # Metallic bevel: brighter crown edge, broad warm face and dark lower lip.
    var image := Image.create_empty(96, 48, false, Image.FORMAT_RGBA8)
    for y in range(48):
        var cut := int(absf(y - 23.5) * 0.56)
        for x in range(cut, 96 - cut):
            var t := float(y) / 47.0
            var tone := Color("#b87a2c").lerp(Color("#f8d789"), clampf(1.0 - absf(t - 0.32) * 1.65, 0.0, 1.0))
            if t > 0.62:
                tone = tone.lerp(Color("#a46b2c"), (t - 0.62) / 0.38 * 0.60)
            if y <= 1 or y == 46 or x - cut < 2 or 95 - cut - x < 2:
                tone = Color("#fff1b6") if y <= 1 else Color("#925c26")
            elif y <= 4:
                tone = tone.lerp(Color("#ffe8a4"), 0.75)
            elif y >= 44:
                tone = tone.lerp(Color("#75491d"), 0.58)
            image.set_pixel(x, y, tone)

    _gold_style = StyleBoxTexture.new()
    _gold_style.texture = ImageTexture.create_from_image(image)
    _gold_style.set_texture_margin(SIDE_LEFT, 22)
    _gold_style.set_texture_margin(SIDE_RIGHT, 22)
    _gold_style.set_expand_margin(SIDE_TOP, -7)
    _gold_style.set_expand_margin(SIDE_BOTTOM, -7)
    return _gold_style

static func heading_font(font: FontVariation) -> FontVariation:
    font.variation_transform = Transform2D(Vector2(1.0, 0.23), Vector2.DOWN, Vector2.ZERO)
    return font

static func panel_style(background: Color, edge: Color, padding: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.set_content_margin_all(padding)
    return style

static func action_button(text: String, font: Font, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 56
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_override("font", font)
    button.add_theme_font_size_override("font_size", 15)
    var ink := Color("#111a26")
    var text_color := ink if primary else Color("#f7f4ec")
    for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
        button.add_theme_color_override(state, text_color)
    var normal: StyleBox = gold_button_style() if primary else _button_frame(ink, GOLD_DARK)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal if primary else _button_frame(Color("#243549"), GOLD))
    button.add_theme_stylebox_override("pressed", _button_frame(GOLD_DARK if primary else Color("#101e2c"), GOLD_BRIGHT))
    button.add_theme_stylebox_override("disabled", _button_frame(Color("#25303c"), Color("#536170")))
    button.add_theme_color_override("font_disabled_color", Color("#9cabb8"))
    return button

static func _button_frame(background: Color, edge: Color) -> StyleBoxFlat:
    var style := panel_style(background, edge, 5)
    style.set_expand_margin(SIDE_TOP, -7)
    style.set_expand_margin(SIDE_BOTTOM, -7)
    return style

static func beveled_panel_style(background: Color, edge: Color, padding: int) -> StyleBoxTexture:
    var key := "%s:%s:%d" % [background.to_html(), edge.to_html(), padding]
    if not _beveled_styles.has(key):
        var size := 32
        var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
        for y in range(size):
            for x in range(size):
                var dx := mini(x, size - 1 - x)
                var dy := mini(y, size - 1 - y)
                if dx + dy < 7:
                    continue
                var tint := background.darkened(0.14).lerp(background.lightened(0.07), 1.0 - float(y) / (size - 1))
                if dx == 0 or dy == 0 or dx + dy == 7:
                    tint = edge.lerp(GOLD_BRIGHT, 0.20 if y < 8 else 0.0)
                elif dx == 1 or dy == 1 or dx + dy == 8:
                    tint = background.lerp(edge, 0.28)
                image.set_pixel(x, y, tint)
        var style := StyleBoxTexture.new()
        style.texture = ImageTexture.create_from_image(image)
        for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
            style.set_texture_margin(side, 9)
        style.set_content_margin_all(padding)
        _beveled_styles[key] = style
    return _beveled_styles[key]
