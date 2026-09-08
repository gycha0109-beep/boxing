extends "res://scripts/main_v15.gd"

const V16_ACCENT := Color(0.94, 0.72, 0.31, 1.0)
const V16_MUTED := Color(0.67, 0.70, 0.76, 1.0)
const V16_PANEL := Color(0.055, 0.065, 0.085, 0.98)
const V16_PANEL_ALT := Color(0.075, 0.085, 0.11, 0.98)
const V16_BORDER := Color(0.18, 0.22, 0.29, 1.0)
const V16_DANGER := Color(0.94, 0.35, 0.33, 1.0)
const V16_SUCCESS := Color(0.32, 0.75, 0.56, 1.0)

var stat_help_dialog: AcceptDialog

func _ready() -> void:
    VisualAssetCatalog.install_identity_visual_profiles()
    super._ready()

func _render_camp() -> void:
    _v16_heading("TRAINING CAMP", "이번 캠프에서 한 가지에 집중합니다.")
    _render_player_visual_card()
    var grid: GridContainer = _v16_grid(2)
    for action_value in camp_actions:
        _v16_camp_card(grid, action_value as Dictionary)
    var shop := Button.new()
    shop.text = "장비 · 투자 보기"
    shop.custom_minimum_size = Vector2(0, 56)
    shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shop.mouse_filter = Control.MOUSE_FILTER_PASS
    shop.pressed.connect(Callable(self, "_open_equipment_shop"))
    body.add_child(shop)
    _render_career_ladder_card()
    _render_active_legacy_summary()

func _render_offers() -> void:
    _v16_heading("FIGHT WEEK", "다음 상대를 선택하세요.")
    _render_player_visual_card()
    var offers: Array = GameState.get_fight_offers(opponents)
    for opponent_value in offers:
        _v16_offer_card(opponent_value as Dictionary)
    _render_career_ladder_card()

func _render_game_plan() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v16_heading("GAME PLAN", "상대의 습관에 맞춰 한 가지 플랜을 고릅니다.")
    _render_player_visual_card()
    _v16_opponent_card(current_opponent, "NEXT OPPONENT")
    var scouting: Dictionary = current_opponent.get("scouting", {})
    var read := _v16_panel(body, "SCOUTING READ")
    _v16_label(read, "강점 · %s" % str(scouting.get("strength", "정보 부족")), false)
    _v16_label(read, "약점 · %s" % str(scouting.get("weakness", "정보 부족")), true)
    var suggested: Array = scouting.get("suggested_plans", [])
    var grid: GridContainer = _v16_grid(2)
    for plan_value in GameState.game_plans:
        var plan: Dictionary = plan_value
        var recommended: bool = str(plan.get("id", "")) in suggested
        var card := _v16_panel(grid, ("★ " if recommended else "") + str(plan.get("name", "플랜")), recommended)
        _v16_badge(card, "리스크 · %s" % str(plan.get("risk", "중간")), V16_DANGER if str(plan.get("risk", "")) == "높음" else V16_MUTED)
        _v16_label(card, _v16_one_line(str(plan.get("description", "")), 42), true)
        _v16_label(card, _v16_one_line(_plan_effect_text(plan), 44), false)
        var choose := _v16_cta("이 플랜 선택")
        choose.pressed.connect(Callable(self, "_choose_game_plan").bind(str(plan.get("id", ""))))
        card.add_child(choose)
    var back := _v16_secondary_button("← 상대 다시 선택")
    back.pressed.connect(Callable(self, "_return_to_fight_offers"))
    body.add_child(back)

func _render_tactical_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v16_heading("TACTICAL PREP", "이번 상대를 위한 전술 하나만 준비합니다.")
    _render_player_visual_card()
    _v16_opponent_card(current_opponent, "OPPONENT")
    var grid: GridContainer = _v16_grid(2)
    for prep_value in GameState.tactical_preparations():
        var prep: Dictionary = prep_value
        var card := _v16_panel(grid, str(prep.get("name", "전술")))
        _v16_label(card, _v16_one_line(str(prep.get("description", "")), 42), true)
        _v16_label(card, _v16_tactical_effect(prep), false)
        var choose := _v16_cta("이 전술 준비")
        choose.pressed.connect(Callable(self, "_choose_tactical_preparation").bind(str(prep.get("id", ""))))
        card.add_child(choose)
    var back := _v16_secondary_button("← 상대 다시 선택")
    back.pressed.connect(Callable(self, "_return_from_tactical_to_offers"))
    body.add_child(back)

func _render_condition_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v16_heading("FIGHT WEEK PREP", "마지막 몸 상태만 정리합니다.")
    _render_player_visual_card()
    _v16_opponent_card(current_opponent, "NEXT FIGHT")
    var tactical: Dictionary = GameState.preparation_definition("tactical", str(GameState.state.get("selected_tactical_prep", "")))
    if not tactical.is_empty():
        var selected := _v16_panel(body, "선택한 전술 · %s" % str(tactical.get("name", "")), true)
        _v16_label(selected, _v16_one_line(str(tactical.get("description", "")), 60), true)
    var grid: GridContainer = _v16_grid(2)
    for prep_value in GameState.condition_preparations():
        var prep: Dictionary = prep_value
        var card := _v16_panel(grid, str(prep.get("name", "준비")))
        _v16_label(card, _v16_one_line(str(prep.get("description", "")), 42), true)
        _v16_label(card, _v16_condition_effect(prep), false)
        var choose := _v16_cta("이 준비 선택")
        choose.pressed.connect(Callable(self, "_choose_condition_preparation").bind(str(prep.get("id", ""))))
        card.add_child(choose)
    var back := _v16_secondary_button("← 전술 준비 다시 선택")
    back.pressed.connect(Callable(self, "_return_to_tactical_preparation"))
    body.add_child(back)

func _render_style_select() -> void:
    _v16_heading("BOXER CREATION", "복싱 스타일은 출발점입니다. 이후 훈련으로 바꿔갈 수 있습니다.")
    var grid: GridContainer = _v16_grid(2)
    for style_value in GameState.boxing_styles():
        var style_data: Dictionary = style_value
        var card := _v16_panel(grid, str(style_data.get("name", "균형형")))
        _v16_label(card, _v16_one_line(str(style_data.get("signature", "")), 28), false)
        _v16_label(card, _v16_one_line(str(style_data.get("description", "")), 46), true)
        _v16_label(card, _visible_stat_bonus(style_data.get("stat_bonus", {})), false)
        _v16_label(card, _style_training_hint(str(style_data.get("id", "balanced"))), true)
        var choose := _v16_cta("이 스타일로 시작")
        choose.pressed.connect(Callable(self, "_choose_boxing_style").bind(str(style_data.get("id", "balanced"))))
        card.add_child(choose)

func _render_player_visual_card() -> void:
    var texture: Texture2D = VisualAssetCatalog.portrait_texture(true)
    if texture == null:
        return
    var card := _v16_panel(body, "내 선수 · YOUR FIGHTER")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    card.add_child(row)
    row.add_child(_v16_portrait(texture, 92.0))
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    row.add_child(info)
    var name_label := Label.new()
    name_label.text = str(boxer.get("name", "BOXER"))
    name_label.add_theme_font_size_override("font_size", 20)
    info.add_child(name_label)
    _v16_label(info, "복싱 스타일 · %s  |  재능 · %s" % [str(boxer.get("identity_name", "균형형")), str(boxer.get("trait_name", ""))], true)
    _v16_label(info, "%d전 %d승 %d패 %d무 · 랭킹 #%d" % [int(career.get("fights", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), int(career.get("rank", 0))], true)
    _v16_label(info, "현재 상태 · 체중 %.1fkg · 피로 %d%% · 건강 %d%%" % [float(boxer.get("weight_kg", 0.0)), int(boxer.get("fatigue", 0)), int(boxer.get("health", 0))], false)
    var stats_title := Label.new()
    stats_title.text = "능력치"
    stats_title.add_theme_font_size_override("font_size", 17)
    stats_title.add_theme_color_override("font_color", V16_ACCENT)
    card.add_child(stats_title)
    for stat_id in ["power", "speed", "technique", "defense", "conditioning"]:
        _v16_stat_row(card, stat_id, int(boxer.get(stat_id, 0)))

func _v16_camp_card(parent: GridContainer, action: Dictionary) -> void:
    var affordable: bool = int(GameState.state.career.money) >= int(action.get("cost", 0))
    var card := _v16_panel(parent, str(action.get("name", "캠프")))
    var icon_texture: Texture2D = _v16_training_icon(str(action.get("id", "")))
    if icon_texture != null:
        var icon := TextureRect.new()
        icon.texture = icon_texture
        icon.custom_minimum_size = Vector2(42, 42)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(icon)
    _v16_badge(card, "%d원 · 부상 %.1f%%" % [int(action.get("cost", 0)), float(action.get("risk", 0.0)) * 100.0], V16_DANGER if float(action.get("risk", 0.0)) >= 0.07 else V16_MUTED)
    var effect_value: Variant = action.get("effects", {})
    var effects: Dictionary = effect_value if typeof(effect_value) == TYPE_DICTIONARY else {}
    _v16_label(card, _v16_compact_effects(effects), false)
    if not affordable:
        _v16_badge(card, "자금 부족", V16_DANGER)
    var choose := _v16_cta("캠프 선택" if affordable else "선택 불가")
    choose.disabled = not affordable
    choose.pressed.connect(Callable(self, "_choose_camp_action").bind(action))
    card.add_child(choose)

func _v16_offer_card(opponent: Dictionary) -> void:
    var card := _v16_panel(body, "")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    card.add_child(row)
    row.add_child(_v16_portrait(VisualAssetCatalog.opponent_portrait_texture_for_name(str(opponent.get("name", ""))), 96.0))
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    row.add_child(info)
    var name_label := Label.new()
    name_label.text = "%s  [%s]  ·  #%d" % [str(opponent.get("name", "OPPONENT")), VisualAssetCatalog.opponent_country_badge(str(opponent.get("name", ""))), int(opponent.get("rank", 0))]
    name_label.add_theme_font_size_override("font_size", 18)
    info.add_child(name_label)
    _v16_badge(info, "%s · %s" % [_tier_label(str(opponent.get("tier", ""))), _style_label(str(opponent.get("style", "")))], V16_ACCENT)
    _v16_label(info, "파이트머니 %d원 · 승 +%d / 패 %dpt" % [int(opponent.get("purse", 0)), int(opponent.get("career_points_win", 0)), int(opponent.get("career_points_loss", 0))], true)
    var stats: Dictionary = opponent.get("stats", {})
    _v16_label(info, "P%d · S%d · T%d · D%d · C%d" % [int(stats.get("power", 0)), int(stats.get("speed", 0)), int(stats.get("technique", 0)), int(stats.get("defense", 0)), int(stats.get("conditioning", 0))], false)
    var choose := _v16_cta("상대 분석  ›")
    choose.pressed.connect(Callable(self, "_choose_opponent").bind(opponent))
    info.add_child(choose)

func _v16_opponent_card(opponent: Dictionary, title_text: String) -> void:
    var card := _v16_panel(body, title_text)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    card.add_child(row)
    row.add_child(_v16_portrait(VisualAssetCatalog.opponent_portrait_texture_for_name(str(opponent.get("name", ""))), 88.0))
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    var label := Label.new()
    label.text = "%s  [%s]" % [str(opponent.get("name", "OPPONENT")), VisualAssetCatalog.opponent_country_badge(str(opponent.get("name", "")))]
    label.add_theme_font_size_override("font_size", 18)
    info.add_child(label)
    _v16_label(info, "%s · #%d" % [_style_label(str(opponent.get("style", ""))), int(opponent.get("rank", 0))], true)

func _v16_stat_row(parent: VBoxContainer, stat_id: String, value: int) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)
    var label := Label.new()
    label.text = _stat_label(stat_id)
    label.custom_minimum_size = Vector2(70, 0)
    row.add_child(label)
    var help := Button.new()
    help.text = "?"
    help.tooltip_text = GameState.stat_help(stat_id)
    help.custom_minimum_size = Vector2(44, 44)
    help.mouse_filter = Control.MOUSE_FILTER_PASS
    help.pressed.connect(Callable(self, "_show_stat_help").bind(stat_id))
    row.add_child(help)
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = clampi(value, 0, 100)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 12)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.14, 0.16, 0.20, 1.0)
    bg.set_corner_radius_all(5)
    var fill := StyleBoxFlat.new()
    fill.bg_color = V16_ACCENT
    fill.set_corner_radius_all(5)
    bar.add_theme_stylebox_override("background", bg)
    bar.add_theme_stylebox_override("fill", fill)
    row.add_child(bar)
    var number := Label.new()
    number.text = str(value)
    number.custom_minimum_size = Vector2(30, 0)
    number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(number)

func _show_stat_help(stat_id: String) -> void:
    if not is_instance_valid(stat_help_dialog):
        stat_help_dialog = AcceptDialog.new()
        stat_help_dialog.name = "StatHelpDialog"
        add_child(stat_help_dialog)
    stat_help_dialog.title = _stat_label(stat_id)
    stat_help_dialog.dialog_text = GameState.stat_help(stat_id)
    stat_help_dialog.popup_centered(Vector2i(320, 170))

func _v16_heading(kicker: String, title_text: String) -> void:
    var eyebrow := Label.new()
    eyebrow.text = kicker
    eyebrow.add_theme_font_size_override("font_size", 13)
    eyebrow.add_theme_color_override("font_color", V16_ACCENT)
    body.add_child(eyebrow)
    var title := Label.new()
    title.text = title_text
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_font_size_override("font_size", 22)
    body.add_child(title)

func _v16_grid(columns: int) -> GridContainer:
    var grid := GridContainer.new()
    grid.columns = columns
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    body.add_child(grid)
    return grid

func _v16_panel(parent: Container, title_text: String, highlighted: bool = false) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = V16_PANEL_ALT if highlighted else V16_PANEL
    style.border_color = V16_ACCENT if highlighted else V16_BORDER
    style.set_border_width_all(2 if highlighted else 1)
    style.set_corner_radius_all(13)
    style.content_margin_left = 11.0
    style.content_margin_right = 11.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    panel.add_child(box)
    if not title_text.is_empty():
        var title := Label.new()
        title.text = title_text
        title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        title.add_theme_font_size_override("font_size", 16)
        box.add_child(title)
    return box

func _v16_portrait(texture: Texture2D, extent: float) -> TextureRect:
    var view := TextureRect.new()
    view.texture = texture
    view.custom_minimum_size = Vector2(extent, extent)
    view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    view.clip_contents = true
    return view

func _v16_cta(text_value: String) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 56)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.add_theme_color_override("font_color", V16_ACCENT)
    return button

func _v16_secondary_button(text_value: String) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 56)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    return button

func _v16_label(parent: Container, text_value: String, muted: bool) -> Label:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 12)
    if muted:
        label.add_theme_color_override("font_color", V16_MUTED)
    parent.add_child(label)
    return label

func _v16_badge(parent: Container, text_value: String, color: Color) -> Label:
    var label := _v16_label(parent, text_value, false)
    label.add_theme_color_override("font_color", color)
    return label

func _v16_training_icon(action_id: String) -> Texture2D:
    var icon_name: String = "conditioning"
    match action_id:
        "heavy_bag": icon_name = "power"
        "mitts": icon_name = "speed"
        "roadwork": icon_name = "conditioning"
        "defense_drill": icon_name = "defense"
        "sparring": icon_name = "power"
        "full_rest": icon_name = "health"
        "rehab": icon_name = "injury"
        "weight_cut": icon_name = "weight"
    return VisualAssetCatalog.texture(VisualAssetCatalog.icon_path(icon_name))

func _v16_one_line(text_value: String, max_chars: int) -> String:
    var compact: String = text_value.replace("\n", " ").strip_edges()
    if compact.length() <= max_chars:
        return compact
    return compact.left(max_chars - 1).strip_edges() + "…"

func _v16_compact_effects(effects: Dictionary) -> String:
    var order: Array[String] = ["power", "speed", "technique", "defense", "conditioning", "fatigue", "health", "weight", "injury_camps"]
    var labels := {"power":"파워", "speed":"스피드", "technique":"테크닉", "defense":"수비", "conditioning":"체력", "fatigue":"피로", "health":"건강", "weight":"체중", "injury_camps":"재활"}
    var parts: Array[String] = []
    for key in order:
        if not effects.has(key):
            continue
        var value: float = float(effects[key])
        var sign: String = "+" if value > 0.0 else ""
        if key == "weight":
            parts.append("%s %s%.2fkg" % [str(labels[key]), sign, value])
        else:
            parts.append("%s %s%d" % [str(labels[key]), sign, int(value)])
    if parts.size() <= 2:
        return " · ".join(parts)
    return "%s\n%s" % [" · ".join(parts.slice(0, 2)), " · ".join(parts.slice(2))]

func _v16_tactical_effect(prep: Dictionary) -> String:
    var modifiers: Dictionary = prep.get("action_modifiers", {})
    var labels: Array[String] = []
    for action_key in modifiers.keys():
        match str(action_key):
            "jab": labels.append("잽")
            "power": labels.append("강타")
            "body": labels.append("바디")
            "guard": labels.append("가드")
            "counter": labels.append("카운터")
    return "유리한 행동 · %s" % (" / ".join(labels) if not labels.is_empty() else "균형")

func _v16_condition_effect(prep: Dictionary) -> String:
    var immediate_value: Variant = prep.get("immediate", {})
    var immediate: Dictionary = immediate_value if typeof(immediate_value) == TYPE_DICTIONARY else {}
    var merged: Dictionary = immediate.duplicate(true)
    var global_value: Variant = prep.get("global_stats", {})
    var global_stats: Dictionary = global_value if typeof(global_value) == TYPE_DICTIONARY else {}
    for key in global_stats.keys():
        merged[key] = global_stats[key]
    return _v16_compact_effects(merged)