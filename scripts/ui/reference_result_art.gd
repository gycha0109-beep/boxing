extends RefCounted

const UI := preload("res://scripts/ui/reference_ui.gd")

static var _plates: Dictionary = {}

static func glow(parent: Control, center: Vector2, dimensions: Vector2, tint: Color) -> void:
    var ramp := Gradient.new()
    ramp.offsets = PackedFloat32Array([0.0, 0.13, 0.42, 1.0])
    ramp.colors = PackedColorArray([tint, Color(tint, tint.a * 0.7), Color(tint, tint.a * 0.19), Color(tint, 0)])
    var texture := GradientTexture2D.new()
    texture.gradient = ramp
    texture.width = 256
    texture.height = 96
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    var light := TextureRect.new()
    light.texture = texture
    light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    light.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(light)
    light.anchor_left = center.x
    light.anchor_right = center.x
    light.anchor_top = center.y
    light.anchor_bottom = center.y
    light.offset_left = -dimensions.x * 0.5
    light.offset_right = dimensions.x * 0.5
    light.offset_top = -dimensions.y * 0.5
    light.offset_bottom = dimensions.y * 0.5

static func laurel(parent: Container, height: float, tint: Color, mirrored: bool) -> void:
    var leaf := Control.new()
    leaf.custom_minimum_size = Vector2(height * 0.42, height)
    leaf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leaf.draw.connect(func():
        var stem := PackedVector2Array()
        for i in range(15):
            var ratio := i / 14.0
            stem.append(_sprig_point(leaf.size, ratio, mirrored))
        leaf.draw_polyline(stem, tint.darkened(0.26), 1.15, true)
        for i in range(6):
            var ratio := 0.11 + i * 0.125
            var origin := _sprig_point(leaf.size, ratio, mirrored)
            var length := height * (0.17 - ratio * 0.065)
            var sign_x := -1.0 if mirrored else 1.0
            _leaf(leaf, origin, Vector2(-0.82 * sign_x, -0.70 - ratio).normalized() * length, tint, mirrored)
            _leaf(leaf, origin, Vector2(0.96 * sign_x, -0.28 - ratio).normalized() * length * 0.81, tint.lightened(0.15), mirrored)
    )
    parent.add_child(leaf)

static func _sprig_point(size: Vector2, ratio: float, mirrored: bool) -> Vector2:
    var x := 0.72 - 0.50 * sin(ratio * PI * 0.79)
    return Vector2(size.x * (1.0 - x if mirrored else x), size.y * (0.92 - 0.84 * ratio))

static func _leaf(leaf: Control, origin: Vector2, length: Vector2, tint: Color, mirrored: bool) -> void:
    var edge := length.orthogonal() * (0.24 if mirrored else -0.24)
    var tip := origin + length
    var middle := origin + length * 0.54
    leaf.draw_colored_polygon(PackedVector2Array([origin, middle + edge, tip, middle - edge]), tint.darkened(0.24))
    leaf.draw_colored_polygon(PackedVector2Array([origin, middle + edge, tip]), tint)

static func gold_plate(width: int, height: int, face: Color, outer: int) -> StyleBoxTexture:
    var key := "%d:%d:%s:%d" % [width, height, face.to_html(), outer]
    if _plates.has(key):
        return _plates[key]
    var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
    for y in range(height):
        var v := float(y) / (height - 1)
        var cut := roundi(absf(v - 0.5) * height * 0.63)
        for x in range(cut, width - cut):
            var edge := mini(mini(y, height - 1 - y), mini(x - cut, width - 1 - cut - x))
            var highlight := pow(maxf(0, 1.0 - absf(float(x) / width - 0.49) * 2.4), 3.0)
            var color := face.lerp(Color("#fff0bc"), maxf(0, 0.70 - absf(v - 0.29) * 1.27))
            color = color.darkened(maxf(0, v - 0.63) * 0.73).lightened(highlight * 0.13)
            if edge == 0:
                color = Color("#fff0b9") if v < 0.55 else Color("#966020")
            elif edge < outer:
                color = Color("#563014").lerp(Color("#f9ce7d"), highlight * 0.76)
            elif edge == outer:
                color = Color("#ffd488").lerp(Color("#ffffe5"), highlight * 0.9)
            else:
                color = color.lightened(sin((x + y * 2.7) * 0.62) * 0.025 + 0.025)
            image.set_pixel(x, y, color)
    var style := StyleBoxTexture.new()
    style.texture = ImageTexture.create_from_image(image)
    style.set_texture_margin(SIDE_LEFT, ceili(height * 0.35))
    style.set_texture_margin(SIDE_RIGHT, ceili(height * 0.35))
    style.set_content_margin_all(2)
    _plates[key] = style
    return style

static func result_icon(parent: HBoxContainer, kind: StringName) -> void:
    var icon := Control.new()
    icon.custom_minimum_size = Vector2(16, 16)
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.draw.connect(func(): _draw_icon(icon, kind))
    parent.add_child(icon)

static func _draw_icon(icon: Control, kind: StringName) -> void:
    var gold := UI.GOLD
    var bright := UI.GOLD_BRIGHT
    var dark := UI.GOLD_DARK
    match kind:
        &"opponent":
            icon.draw_circle(Vector2(5, 5), 2.3, bright, true, -1, true)
            icon.draw_circle(Vector2(11, 6), 2.0, gold, true, -1, true)
            icon.draw_arc(Vector2(5, 13), 3.5, PI, TAU, 14, gold, 2.0, true)
            icon.draw_arc(Vector2(11, 13), 3.0, PI, TAU, 14, dark, 1.8, true)
        &"plan", &"scores":
            icon.draw_rect(Rect2(3, 3, 10, 11), dark, false, 1.3, true)
            icon.draw_rect(Rect2(6, 1, 4, 4), bright)
            for y in [7.0, 10.0]:
                icon.draw_line(Vector2(5, y), Vector2(11, y), gold, 1.1, true)
        &"money":
            for offset in [3.0, 0.0]:
                var top := PackedVector2Array([Vector2(1, 7 + offset), Vector2(9, 3 + offset), Vector2(15, 6 + offset), Vector2(7, 10 + offset)])
                icon.draw_colored_polygon(top, dark if offset > 0 else gold)
                icon.draw_polyline(top, bright if offset == 0 else gold, 1.1, true)
        &"rank":
            for i in range(3):
                var bar_height := 5.0 + 3.5 * i
                icon.draw_rect(Rect2(2 + 5 * i, 14 - bar_height, 3, bar_height), gold.lerp(bright, i * 0.35))
        &"career":
            var cup := PackedVector2Array([Vector2(4, 3), Vector2(12, 3), Vector2(11, 8), Vector2(8, 10), Vector2(5, 8)])
            icon.draw_colored_polygon(cup, gold)
            icon.draw_arc(Vector2(8, 4), 6.0, 0, PI, 16, dark, 1.2, true)
            icon.draw_line(Vector2(8, 9), Vector2(8, 14), gold, 1.5, true)
            icon.draw_line(Vector2(4, 14), Vector2(12, 14), bright, 1.4, true)
        &"condition", &"injury":
            icon.draw_line(Vector2(4, 8), Vector2(12, 8), gold, 3, true)
            icon.draw_line(Vector2(8, 4), Vector2(8, 12), bright, 3, true)
        &"commentary":
            icon.draw_circle(Vector2(10, 5), 3.2, bright, true, -1, true)
            icon.draw_line(Vector2(8, 7), Vector2(3, 13), gold, 2.1, true)

static func sparks(parent: Control, side: float) -> void:
    var ember := Control.new()
    ember.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ember.draw.connect(func():
        var random := RandomNumberGenerator.new()
        random.seed = 591
        for i in range(21):
            var x := random.randf_range(0.015, 0.31)
            var center := ember.size * Vector2(x if side < 0.5 else 1.0 - x, random.randf_range(0.12, 0.78))
            var radius := random.randf_range(0.5, 2.5)
            var points := PackedVector2Array([center + Vector2(0, -radius * 1.5), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
            ember.draw_colored_polygon(points, Color(1.0, 0.77, 0.43, random.randf_range(0.24, 0.77)))
    )
    parent.add_child(ember)
