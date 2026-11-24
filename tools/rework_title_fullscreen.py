from pathlib import Path
p=Path(__file__).resolve().parents[1]
view=p/'scripts/ui/reference_title_view.gd'
main=p/'scripts/main_v18_release.gd'
s=view.read_text(encoding='utf-8')
s=s.replace('signal continue_requested()','signal continue_requested()\nsignal settings_requested()')
s=s.replace('var save_caption := ""','var save_caption := ""\nvar settings_icon: Texture2D')
s=s.replace('    size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    add_theme_constant_override("separation", 8)\n    _cover_v2()','    size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    size_flags_vertical = Control.SIZE_EXPAND_FILL\n    add_theme_constant_override("separation", 0)\n    _cover_v2()')
s=s.replace('    cover.custom_minimum_size.y = 834\n    cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL','    cover.custom_minimum_size.y = 0\n    cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    cover.size_flags_vertical = Control.SIZE_EXPAND_FILL')
s=s.replace('    _cover_texture(cover, "res://assets/visual/title_layers_v2/gold_header.png", "TitleGoldHeader", 0, 118)','    _cover_texture(cover, "res://assets/visual/title_layers_v2/gold_header.png", "TitleGoldHeader", 0, 205)')
s=s.replace('    var stadium := _cover_texture(cover, "res://assets/visual/title_layers_v2/arena_clean.png", "TitleArenaBackground", 113, 441)','    var stadium := _cover_texture(cover, "res://assets/visual/title_layers_v2/arena_clean.png", "TitleArenaBackground", 194, 432)')
s=s.replace('    var boxer := _cover_texture(cover, "res://assets/visual/title_layers_v2/boxer_foreground.png", "TitleBoxerForeground", 148, 407)','    var boxer := _cover_texture(cover, "res://assets/visual/title_layers_v2/boxer_foreground.png", "TitleBoxerForeground", 229, 356)')
s=s.replace('    fade_layer.offset_top = 482\n    fade_layer.offset_bottom = 578','    fade_layer.offset_top = 552\n    fade_layer.offset_bottom = 630')
s=s.replace('    shade.offset_top = 113\n    shade.offset_bottom = 166','    shade.offset_top = 176\n    shade.offset_bottom = 244')
s=s.replace('    var title := _cover_label(cover, "TWELVE COUNT", 36, UI.GOLD_BRIGHT, 105, 50, UI.DISPLAY_FONT)','    var title := _cover_label(cover, "TWELVE COUNT", 40, UI.GOLD_BRIGHT, 150, 57, UI.DISPLAY_FONT)')
s=s.replace('    _cover_label(cover, "BOXING CAREER ROGUELITE", 11, PAPER, 149, 22, bold_font)','    _cover_label(cover, "BOXING CAREER ROGUELITE", 12, PAPER, 206, 23, bold_font)')
s=s.replace('    _cover_label(cover, "한 명의 복서, 그리고 이어지는 유산", 15, PAPER, 544, 29, heading_font)','    _cover_label(cover, "데뷔전부터 세계 타이틀전까지", 20, UI.GOLD_BRIGHT, 579, 31, heading_font)\n    _cover_label(cover, "복서를 만들고 커리어를 이어가라", 13, PAPER, 609, 24, bold_font)')
s=s.replace('    _cover_texture(cover, "res://assets/visual/title_layers_v2/button_gold_plate.png", "TitleStartPlate", 575, 90)','    _cover_texture(cover, "res://assets/visual/title_layers_v2/button_gold_plate.png", "TitleStartPlate", 654, 76)')
s=s.replace('    var start := _cover_button(cover, "새 커리어 시작", "TitleNewCareer", 580, 79, 25, Color("#291809"), true)','    var start := _cover_button(cover, "새 커리어 시작", "TitleNewCareer", 660, 63, 24, Color("#291809"), true)')
s=s.replace('    _cover_texture(cover, "res://assets/visual/title_layers_v2/button_dark_plate.png", "TitleResumePlate", 670, 69)','    _cover_texture(cover, "res://assets/visual/title_layers_v2/button_dark_plate.png", "TitleResumePlate", 743, 55)')
s=s.replace('    var resume := _cover_button(cover, "이어하기", "TitleContinue", 677, 58, 20, PAPER, false)','    var resume := _cover_button(cover, "이어하기", "TitleContinue", 746, 50, 20, PAPER, false)')
s=s.replace('    var belt := _cover_texture(cover, "res://assets/visual/title_layers_v2/champion_belt_footer.png", "TitleLegacyBelt", 739, 154)','    var belt := _cover_texture(cover, "res://assets/visual/title_layers_v2/champion_belt_footer.png", "TitleLegacyBelt", 821, 112)')
s=s.replace('        _cover_label(cover, save_caption, 10, MUTED, 811, 18, bold_font).name = "TitleSaveCaption"','        _cover_label(cover, save_caption, 10, MUTED, 804, 17, bold_font).name = "TitleSaveCaption"\n    elif not can_continue:\n        _cover_label(cover, "저장된 커리어가 없습니다", 12, MUTED, 804, 17, bold_font).name = "TitleSaveCaption"\n\n    _cover_settings(cover)\n    cover.resized.connect(_scale_title_layout.bind(cover))\n    call_deferred("_scale_title_layout", cover)')
needle='func _cover_texture(parent: Control, path: String, node_name: String, y: float, height: float) -> TextureRect:'
new='''func _cover_settings(cover: Control) -> void:
    var settings := Button.new()
    settings.name = "TitleSettings"
    settings.tooltip_text = "설정"
    settings.icon = settings_icon
    settings.expand_icon = true
    settings.anchor_left = 1
    settings.anchor_right = 1
    settings.offset_left = -57
    settings.offset_right = -12
    settings.offset_top = 20
    settings.offset_bottom = 65
    settings.focus_mode = Control.FOCUS_ALL
    var border := StyleBoxFlat.new()
    border.bg_color = Color(0.018, 0.026, 0.040, 0.82)
    border.border_color = UI.GOLD_BRIGHT
    border.set_border_width_all(2)
    border.set_corner_radius_all(12)
    for state in ["normal", "hover", "pressed", "focus"]:
        settings.add_theme_stylebox_override(state, border)
    settings.pressed.connect(func(): settings_requested.emit())
    cover.add_child(settings)

func _scale_title_layout(cover: Control) -> void:
    if not is_instance_valid(cover) or cover.size.y <= 0:
        return
    var ratio := cover.size.y / 932.0
    for child in cover.get_children():
        if not child is Control:
            continue
        var item := child as Control
        if not item.has_meta("title_base_top"):
            item.set_meta("title_base_top", item.offset_top)
            item.set_meta("title_base_bottom", item.offset_bottom)
        item.offset_top = float(item.get_meta("title_base_top")) * ratio
        item.offset_bottom = float(item.get_meta("title_base_bottom")) * ratio

'''
if needle not in s: raise RuntimeError('missing title helper')
s=s.replace(needle,new+needle,1)
view.write_text(s,encoding='utf-8')
m=main.read_text(encoding='utf-8')
m=m.replace('    if is_instance_valid(v19_top_bar):\n        v19_top_bar.visible = not in_story or _dev_reset_enabled()','    if is_instance_valid(v19_top_bar):\n        v19_top_bar.visible = not launch_gate_active and (not in_story or _dev_reset_enabled())')
# add reusable fullscreen overlay, keeping HUD hidden only for the title.
needle='func _render_launch_title() -> void:'
start=m.index(needle); end=m.index('func _should_show_launch_title()',start)
block=m[start:end]
block=block.replace('    var previous := body.get_node_or_null("ReferenceTitle")\n    _clear_body()\n    if previous != null:\n        body.remove_child(previous)','    _clear_body()\n    _set_title_shell_visible(false)\n    var previous := get_node_or_null("ReferenceTitle")\n    if previous != null:\n        remove_child(previous)\n        previous.queue_free()')
block=block.replace('    view.name = "ReferenceTitle"','    view.name = "ReferenceTitle"\n    view.settings_icon = _v18_line_icon("settings")')
block=block.replace('    view.continue_requested.connect(_continue_from_reference_title)\n    body.add_child(view)','    view.continue_requested.connect(_continue_from_reference_title)\n    view.settings_requested.connect(_open_title_settings)\n    add_child(view)\n    view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)')
block=block.replace('    _configure_mobile_scroll()','    _configure_mobile_scroll()')
m=m[:start]+block+m[end:]
needle='func _should_show_launch_title() -> bool:'
helper='''func _set_title_shell_visible(visible: bool) -> void:
    for child in get_children():
        if child is MarginContainer:
            child.visible = visible

func _leave_title_overlay() -> void:
    var title := get_node_or_null("ReferenceTitle")
    if title != null:
        remove_child(title)
        title.queue_free()
    _set_title_shell_visible(true)

func _open_title_settings() -> void:
    _leave_title_overlay()
    _v19_open_settings()

'''
m=m.replace(needle,helper+needle,1)
m=m.replace('func _render_phase() -> void:\n    if launch_gate_active:', 'func _render_phase() -> void:\n    if not launch_gate_active:\n        _leave_title_overlay()\n    if launch_gate_active:',1)
main.write_text(m,encoding='utf-8')
print('UPDATED',view,main)
