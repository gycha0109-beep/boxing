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
