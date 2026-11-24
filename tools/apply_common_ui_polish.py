from pathlib import Path
p=Path(r'D:\cha\boxing-current\scripts\main_v17.gd')
s=p.read_text('utf-8')
changes={
'const V17_BG := Color(0.015, 0.023, 0.034, 1.0)':'const V17_BG := Color("#0a1018")',
'const V17_PANEL := Color(0.025, 0.045, 0.067, 0.985)':'const V17_PANEL := Color("#141e29")',
'const V17_PANEL_2 := Color(0.035, 0.060, 0.086, 0.985)':'const V17_PANEL_2 := Color("#1a2632")',
'const V17_PANEL_SOFT := Color(0.045, 0.075, 0.105, 0.94)':'const V17_PANEL_SOFT := Color("#1b2732")',
'const V17_BORDER := Color(0.17, 0.25, 0.34, 1.0)':'const V17_BORDER := Color("#43505c")',
'const V17_GOLD := Color(0.94, 0.69, 0.28, 1.0)':'const V17_GOLD := Color("#e2b966")',
'const V17_GOLD_SOFT := Color(0.67, 0.48, 0.20, 1.0)':'const V17_GOLD_SOFT := Color("#a78652")',
'const V17_MUTED := Color(0.62, 0.67, 0.73, 1.0)':'const V17_MUTED := Color("#b7bdc6")',
'label.add_theme_font_size_override("font_size", 12); label.add_theme_color_override("font_color", V17_MUTED if muted else V17_TEXT)':'label.add_theme_font_size_override("font_size", 13); label.add_theme_color_override("font_color", V17_MUTED if muted else V17_TEXT)',
'style.shadow_color = Color(0, 0, 0, 0.24); style.shadow_size = 3; return style':'style.shadow_color = Color(0, 0, 0, 0.28); style.shadow_size = 2; return style'
}
for a,b in changes.items():
 if a not in s: raise ValueError(a)
 s=s.replace(a,b,1)
p.write_text(s,encoding='utf-8')
p=Path(r'D:\cha\boxing-current\scripts\ui\reference_ui.gd')
s=p.read_text('utf-8')
changes={
'const GOLD_DARK := Color("#9f753c")':'const GOLD_DARK := Color("#ae8246")',
'style.set_corner_radius_all(5)':'style.set_corner_radius_all(7)',
'var ink := Color("#0a1420")':'var ink := Color("#111a26")',
'button.add_theme_font_size_override("font_size", 14)':'button.add_theme_font_size_override("font_size", 15)'
}
for a,b in changes.items():
 if a not in s: raise ValueError(a)
 s=s.replace(a,b,1)
p.write_text(s,encoding='utf-8')
print('Applied common palette, secondary text, panel geometry and button hierarchy.')
