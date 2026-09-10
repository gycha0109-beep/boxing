extends "res://scripts/main_v18.gd"

# Final release authority for the approved v18 commercial shell. Keep visual
# composition in main_v18.gd; this wrapper only enforces release ergonomics,
# pins the shell to validated binary image resources, and restores the compact
# five-stat/career context that must remain visible in camp.
const V18_HERO_TEXTURE: Texture2D = preload("res://assets/visual/v18/hero_player.webp")
const V18_TRAINING_TEXTURE: Texture2D = preload("res://assets/visual/v18/training_atlas.webp")
const V18_OPPONENT_TEXTURE: Texture2D = preload("res://assets/visual/v18/opponent_atlas.webp")
const V18_RING_TEXTURE: Texture2D = preload("res://assets/visual/v18/fight_ring_scene.webp")

func _v18_photo(key: String) -> Texture2D:
    match key:
        "hero": return V18_HERO_TEXTURE
        "training": return V18_TRAINING_TEXTURE
        "opponents": return V18_OPPONENT_TEXTURE
        "ring": return V18_RING_TEXTURE
        _: return null

func _render_camp() -> void:
    _v17_player_hero("훈련 캠프 선택", "땀은 배신하지 않는다.")

    _v17_section_heading("훈련 캠프 선택", "")
    var core_ids := ["mitts", "roadwork", "heavy_bag", "defense_drill"]
    var grid := _v17_grid(2)
    for action_id in core_ids:
        for action_value in camp_actions:
            var action: Dictionary = action_value
            if str(action.get("id", "")) == action_id:
                _v17_training_card(grid, action)

    var manage := _v17_secondary_button("회복 · 체중 · 스파링 관리 %s" % ("접기 ▲" if v17_manage_expanded else "보기 ▼"))
    manage.pressed.connect(func():
        v17_manage_expanded = not v17_manage_expanded
        _render_phase()
    )
    body.add_child(manage)
    if v17_manage_expanded:
        _v17_section_heading("컨디션 관리", "필요할 때만 펼쳐보는 보조 선택지입니다.")
        var management := _v17_grid(2)
        for action_value in camp_actions:
            var action: Dictionary = action_value
            if str(action.get("id", "")) not in core_ids:
                _v17_training_card(management, action)

    var shop := _v17_secondary_button("장비 · 체육관 투자  ›")
    shop.pressed.connect(Callable(self, "_open_equipment_shop"))
    body.add_child(shop)

func _render_tactical_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v17_matchup_strip("전술 준비", "영구 성장 없이, 상대의 습관에 맞춰 한 가지 흐름을 준비합니다.")
    var grid := _v17_grid(2)
    for prep_value in GameState.tactical_preparations():
        var prep: Dictionary = prep_value
        var card := _v17_panel(grid, false)
        _v17_title(card, str(prep.get("name", "전술")), 18)
        _v17_copy(card, _v16_one_line(str(prep.get("description", "")), 54), true)
        _v17_chip(card, _v16_tactical_effect(prep), V17_GOLD)
        var choose := _v17_gold_button("이 전술 준비")
        choose.pressed.connect(Callable(self, "_choose_tactical_preparation").bind(str(prep.get("id", ""))))
        card.add_child(choose)
    var back := _v17_secondary_button("← 상대 다시 선택")
    back.pressed.connect(Callable(self, "_return_from_tactical_to_offers"))
    body.add_child(back)

func _render_offers() -> void:
    _v17_offer_hero()
    var grid := _v17_grid(2)
    var offers: Array = GameState.get_fight_offers(opponents)
    for index in range(offers.size()):
        var opponent: Dictionary = offers[index]
        var card := _v17_panel(grid, index == 0)
        card.name = "OpponentCard_" + str(opponent.get("id", index))
        var portrait := TextureRect.new()
        portrait.texture = _v17_opponent_texture(opponent)
        portrait.custom_minimum_size = Vector2(0, 80)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        card.add_child(portrait)
        _v17_title(card, "%s %s" % [_v17_opponent_name(opponent), _v17_flag(_v17_country(opponent))], 16)
        _v17_copy(card, _style_label(str(opponent.get("style", ""))), true)
        var stats: Dictionary = opponent.get("stats", {})
        _v17_copy(card, "파워 %d · 스피드 %d\n테크닉 %d · 수비 %d · 체력 %d" % [int(stats.get("power", 0)), int(stats.get("speed", 0)), int(stats.get("technique", 0)), int(stats.get("defense", 0)), int(stats.get("conditioning", 0))], false)
        var purse := _v17_title(card, "%s원" % _v17_money(int(opponent.get("purse", 0))), 18)
        purse.add_theme_color_override("font_color", V17_GOLD)
        _v17_copy(card, "승리 +%dpt · 패배 -%dpt" % [int(opponent.get("career_points_win", 0)), abs(int(opponent.get("career_points_loss", 0)))], true)
        var choose := _v17_gold_button("도전 수락  ›")
        choose.pressed.connect(Callable(self, "_choose_opponent").bind(opponent))
        card.add_child(choose)
    _v17_career_progress_strip()

func _configure_mobile_scroll() -> void:
    if not is_instance_valid(body):
        return
    # v17 inserted a MarginContainer between body and the content scroll.
    # Resolve the shell scroll explicitly so fight mode remains a fixed HUD.
    var scroll := find_child("V17ContentScroll", true, false) as ScrollContainer
    if scroll == null:
        super._configure_mobile_scroll()
        return
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    if str(GameState.state.get("phase", "")) == "fight":
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.scroll_vertical = 0
    else:
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    _configure_scroll_input_tree(body)

func _v17_top_bar() -> Control:
    var bar := HBoxContainer.new()
    bar.custom_minimum_size.y = 76
    bar.add_theme_constant_override("separation", 4)
    var menu := Button.new()
    menu.icon = _v18_line_icon("menu")
    menu.flat = true
    menu.custom_minimum_size = Vector2(56, 56)
    menu.pressed.connect(Callable(self, "_v17_open_overlay").bind("profile"))
    bar.add_child(menu)
    var brand := VBoxContainer.new()
    brand.alignment = BoxContainer.ALIGNMENT_CENTER
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.add_theme_constant_override("separation", 0)
    bar.add_child(brand)
    var crown := TextureRect.new()
    crown.texture = _v18_line_icon("crown")
    crown.custom_minimum_size.y = 18
    crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    brand.add_child(crown)
    var title := _v17_title(brand, "TWELVE COUNT", 21)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", V17_GOLD)
    var subtitle := _v17_copy(brand, "B O X I N G   C A R E E R", true)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 8)
    var account := VBoxContainer.new()
    account.custom_minimum_size.x = 76
    account.alignment = BoxContainer.ALIGNMENT_CENTER
    bar.add_child(account)
    v17_money_label = _v17_copy(account, "0원", false)
    v17_money_label.add_theme_font_size_override("font_size", 11)
    var gear := Button.new()
    gear.icon = _v18_line_icon("settings")
    gear.flat = true
    gear.custom_minimum_size = Vector2(56, 56)
    gear.disabled = true
    gear.tooltip_text = "설정 준비 중"
    bar.add_child(gear)
    return bar

func _apply_v07_system_font() -> void:
    super._apply_v07_system_font()
    # The variable font's default axis is Thin. Explicitly select readable weights.
    var regular := _v18_font(450)
    for type_name in ["Label", "Button", "LineEdit"]:
        theme.set_font("font", type_name, regular)

func _apply_safe_area() -> void:
    if not is_inside_tree(): return
    safe_insets = SafeAreaLayout.current_insets(get_viewport_rect().size)
    var margin := _shell_margin()
    if margin == null: return
    for side in ["left", "right", "top", "bottom"]:
        var padding := 12 if side in ["left", "right"] else 8
        margin.add_theme_constant_override("margin_" + side, padding + int(ceil(float(safe_insets.get(side, 0)))))

func _v18_font(weight: int) -> FontVariation:
    var font := FontVariation.new()
    font.base_font = load(RELEASE_FONT_PATH)
    font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight)}
    return font

func _v17_title(parent: Container, text_value: String, font_size: int) -> Label:
    var label := super._v17_title(parent, text_value, font_size)
    label.add_theme_font_override("font", _v18_font(750))
    return label

func _v17_eyebrow(parent: Container, text_value: String) -> Label:
    var label := super._v17_eyebrow(parent, text_value)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 10)
    return label

func _v17_section_heading(title_text: String, subtitle: String) -> void:
    var title := _v17_title(body, title_text, 24)
    title.add_theme_color_override("font_color", V17_GOLD)
    if not subtitle.is_empty():
        _v17_copy(body, subtitle, true)

func _v17_metrics(parent: VBoxContainer) -> void:
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 8)
    parent.add_child(grid)
    _v17_metric(grid, "체중", "%.1fkg" % float(boxer.get("weight_kg", 0)), V17_TEXT)
    _v17_metric(grid, "피로", "%d%%" % int(boxer.get("fatigue", 0)), V17_DANGER)
    _v17_metric(grid, "건강", "%d%%" % int(boxer.get("health", 0)), V17_GOLD)
    _v17_metric(grid, "보유금", "%s원" % _v17_money(int(career.get("money", 0))), V17_TEXT)

func _v17_training_card(parent: GridContainer, action: Dictionary) -> void:
    var affordable := int(GameState.state.career.get("money", 0)) >= int(action.get("cost", 0))
    var card := _v17_panel(parent, false)
    card.name = "CampCard_" + str(action.id)
    card.add_theme_constant_override("separation", 4)
    _v17_training_art(card, str(action.id))
    _v17_title(card, _v17_training_name(action), 17)
    var description := _v17_copy(card, _v17_training_description(str(action.id)), true)
    description.custom_minimum_size.y = 34
    description.add_theme_font_size_override("font_size", 11)
    var meta := _v17_copy(card, "%s원 · 부상 %.1f%%" % [_v17_money(int(action.cost)), float(action.risk) * 100], false)
    meta.add_theme_font_size_override("font_size", 11)
    _v17_effect_grid(card, action.get("effects", {}))
    var space := Control.new()
    space.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_child(space)
    var choose := _v17_gold_button("캠프 선택  ›" if affordable else "자금 부족")
    choose.disabled = not affordable
    choose.pressed.connect(Callable(self, "_choose_camp_action").bind(action))
    card.add_child(choose)

func _v17_fight_action(parent: GridContainer, action_id: String, selected_plan: Dictionary) -> void:
    super._v17_fight_action(parent, action_id, selected_plan)
    var button := parent.get_child(parent.get_child_count() - 1) as Button
    var icon_id: String = {"jab": "speed", "power": "power", "body": "conditioning", "guard": "defense", "counter": "technique"}.get(action_id, "power")
    # Existing licensed icon pack; do not add an extra gameplay action to fill the grid.
    var path := "res://assets/visual/v0.7/icons/icon_%s.png" % icon_id
    if ResourceLoader.exists(path):
        button.icon = load(path)
        button.expand_icon = true
        button.add_theme_constant_override("icon_max_width", 24)

func _v17_panel(parent: Container, highlighted: bool) -> VBoxContainer:
    var panel := super._v17_panel(parent, highlighted)
    panel.add_theme_constant_override("separation", 4)
    panel.get_parent().add_theme_stylebox_override("panel", _v17_box_style(V17_PANEL_2 if highlighted else V17_PANEL, V17_GOLD if highlighted else V17_BORDER, 10, 8))
    return panel

func _v17_chip(parent: Container, text_value: String, color: Color) -> Label:
    var label := super._v17_chip(parent, text_value, color)
    label.get_parent().add_theme_stylebox_override("panel", _v17_box_style(Color("102131"), Color(color.r, color.g, color.b, 0.45), 5, 2))
    return label

func _show_stat_help(stat_id: String) -> void:
    if not is_instance_valid(stat_help_dialog):
        stat_help_dialog = AcceptDialog.new()
        stat_help_dialog.name = "StatHelpDialog"
        stat_help_dialog.borderless = true
        stat_help_dialog.dialog_autowrap = true
        stat_help_dialog.theme = theme.duplicate()
        stat_help_dialog.theme.set_stylebox("panel", "AcceptDialog", _v17_box_style(V17_PANEL, V17_BLUE, 10, 16))
        stat_help_dialog.theme.set_font("font", "Label", _v18_font(500))
        stat_help_dialog.get_label().add_theme_font_size_override("font_size", 15)
        stat_help_dialog.get_ok_button().text = "닫기"
        stat_help_dialog.get_ok_button().custom_minimum_size = Vector2(80, 44)
        add_child(stat_help_dialog)
    stat_help_dialog.title = _stat_label(stat_id)
    stat_help_dialog.dialog_text = "%s\n\n%s" % [_stat_label(stat_id), GameState.stat_help(stat_id)]
    stat_help_dialog.popup_centered(Vector2i(300, 150))

func _v17_prep_symbol(parent: VBoxContainer, prep_id: String) -> void:
    var art := TextureRect.new()
    art.texture = _v18_line_icon("rest" if prep_id in ["rest", "full_rest"] else ("weight" if prep_id == "weight_control" else "training"))
    art.custom_minimum_size = Vector2(40, 40)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    parent.add_child(art)

func _v17_gold_button(text_value: String) -> Button:
    var button := super._v17_gold_button(text_value)
    button.custom_minimum_size.y = 44
    button.add_theme_font_override("font", _v18_font(700))
    var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="56"><defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#f2c875"/><stop offset="1" stop-color="#a57632"/></linearGradient></defs><rect x="1" y="1" width="62" height="54" rx="9" fill="url(#gold)" stroke="#edc77e"/></svg>'
    var image := Image.new()
    image.load_svg_from_string(svg)
    var style := StyleBoxTexture.new()
    style.texture = ImageTexture.create_from_image(image)
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        style.set_texture_margin(side, 12)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    button.add_theme_stylebox_override("normal", style)
    return button

func _v17_dark_button(text_value: String) -> Button:
    var button := super._v17_dark_button(text_value)
    button.custom_minimum_size.y = 44
    return button

func _v17_nav_button(parent: HBoxContainer, key: String, text_value: String, callback: Callable) -> void:
    super._v17_nav_button(parent, key, text_value, callback)
    var button: Button = v17_nav_buttons[key]
    button.text = text_value.get_slice("\n", 1)
    button.icon = _v18_line_icon(key)
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

func _v18_line_icon(key: String) -> Texture2D:
    var paths := {
        "menu": '<path d="M4 6h24M4 16h24M4 26h24"/>',
        "rest": '<path d="M3 5v24m26-16v16M3 24h26M3 15h22a4 4 0 0 1 4 4v5H3z"/><circle cx="9" cy="10" r="3"/>',
        "weight": '<rect x="5" y="3" width="22" height="26" rx="4"/><path d="M10 9a8 8 0 0 1 12 0l-6 6zM16 6v7"/>',
        "settings": '<circle cx="16" cy="16" r="8"/><circle cx="16" cy="16" r="3"/><path d="M16 2v5m0 18v5M2 16h5m18 0h5M6 6l4 4m12 12l4 4M26 6l-4 4M10 22l-4 4"/>',
        "crown": '<path d="M4 9l6 6 6-11 6 11 6-6-3 16H7zM7 29h18"/>',
        "profile": '<circle cx="16" cy="9" r="6"/><path d="M5 29v-5a11 11 0 0 1 22 0v5z"/>',
        "match": '<path d="M8 23L5 16Q4 5 15 4q12 0 12 10l-5 9-5 6zM8 23l9 6"/>',
        "training": '<path d="M3 10v12m5-16v20m16-20v20m5-16v12M8 16h16"/>',
        "career": '<path d="M9 3h14v11a7 7 0 0 1-14 0zM9 6H3v6q0 7 8 7m12-13h6v6q0 7-8 7M16 21v8m-7 0h14"/>',
        "shop": '<path d="M5 13v16h22V13M3 13l3-9h20l3 9zM12 29V19h8v10"/>'
    }
    var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 32 32"><g fill="none" stroke="#e7bd70" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % str(paths.get(key, paths.menu))
    var image := Image.new()
    image.load_svg_from_string(svg)
    return ImageTexture.create_from_image(image)

func _v18_release_touch_targets(node: Node) -> void:
    if node is Button:
        var button := node as Button
        button.custom_minimum_size = Vector2(
            maxf(button.custom_minimum_size.x, 56.0),
            maxf(button.custom_minimum_size.y, 56.0)
        )
    for child in node.get_children():
        _v18_release_touch_targets(child)
