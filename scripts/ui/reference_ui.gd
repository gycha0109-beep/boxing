extends RefCounted

const GOLD := Color("#efc46f")
const GOLD_BRIGHT := Color("#ffe2a0")
const GOLD_DARK := Color("#9f753c")

static var _gold_style: StyleBoxTexture

static func gold_button_style() -> StyleBoxTexture:
    if _gold_style != null:
        return _gold_style

    var image := Image.create_empty(64, 43, false, Image.FORMAT_RGBA8)
    for y in range(43):
        var cut := int(absf(y - 21.0) * 0.65)
        for x in range(cut, 64 - cut):
            var tone := absf(float(y - 13)) / 30.0
            var color := Color("#ffe298").lerp(Color("#b77b32"), tone)
            if y < 2 or y >= 41 or x - cut < 2 or 63 - cut - x < 2:
                color = GOLD_BRIGHT if y < 22 else GOLD_DARK
            image.set_pixel(x, y, color)

    _gold_style = StyleBoxTexture.new()
    _gold_style.texture = ImageTexture.create_from_image(image)
    _gold_style.set_texture_margin(SIDE_LEFT, 16)
    _gold_style.set_texture_margin(SIDE_RIGHT, 16)
    _gold_style.set_expand_margin(SIDE_TOP, -7)
    _gold_style.set_expand_margin(SIDE_BOTTOM, -7)
    return _gold_style

static func heading_font(font: FontVariation) -> FontVariation:
    font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.15, 1), Vector2.ZERO)
    return font

static func panel_style(background: Color, edge: Color, padding: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.set_content_margin_all(padding)
    return style

static func action_button(text: String, font: Font, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 56
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_override("font", font)
    button.add_theme_font_size_override("font_size", 14)
    var ink := Color("#0a1420")
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
