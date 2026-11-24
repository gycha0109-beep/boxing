from pathlib import Path
p=Path(r'D:\cha\boxing-current\scripts\ui\reference_ui.gd')
s=p.read_text('utf-8')
a=s.index('    var image := Image.create_empty(64, 43, false, Image.FORMAT_RGBA8)',s.index('static func gold_button_style'))
b=s.index('\n    _gold_style = StyleBoxTexture.new()',a)
s=s[:a]+'''    # Metallic bevel: brighter crown edge, broad warm face and dark lower lip.
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
''' + s[b:]
s=s.replace('    _gold_style.set_texture_margin(SIDE_LEFT, 16)','    _gold_style.set_texture_margin(SIDE_LEFT, 22)')
s=s.replace('    _gold_style.set_texture_margin(SIDE_RIGHT, 16)','    _gold_style.set_texture_margin(SIDE_RIGHT, 22)')
p.write_text(s,encoding='utf-8')
p=Path(r'D:\cha\boxing-current\scripts\main_v18_release_base.gd')
s=p.read_text('utf-8')
start=s.index('    var svg := ',s.index('func _v17_gold_button'))
end=s.index('    return button',start)
s=s[:start]+'''    var gold_style := preload("res://scripts/ui/reference_ui.gd").gold_button_style()
    button.add_theme_stylebox_override("normal", gold_style)
    button.add_theme_stylebox_override("hover", gold_style)
    button.add_theme_stylebox_override("pressed", _v17_box_style(Color("#a67338"), Color("#ffdf98"), 8, 8))
    button.add_theme_stylebox_override("focus", _v17_box_style(Color.TRANSPARENT, Color("#ffe2a0"), 8, 0))
    button.add_theme_color_override("font_hover_color", Color("#12171d"))
    button.add_theme_color_override("font_pressed_color", Color("#12171d"))
''' + s[end:]
p.write_text(s,encoding='utf-8')
print('Primary metallic buttons applied.')
