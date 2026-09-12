extends "res://scripts/main_v18_release_base.gd"

# v19 real-device UI pass. No generated image assets: this layer only changes
# layout, typography, hierarchy and procedural fight feedback on top of the
# validated v18 release/runtime stack.
const V19_READ_LABEL := "상대 읽기"

var v19_top_bar: HBoxContainer
var v19_menu_button: Button
var v19_money_box: Control
var v19_settings_button: Button
var v19_bottom_nav: Control

func _ready() -> void:
    _v19_disable_legacy_bitmap_fx()
    super._ready()
    _v19_apply_phase_chrome()

func _v19_disable_legacy_bitmap_fx() -> void:
    # The v0.7 impact PNGs contain baked rectangular backplates on-device.
    # Keep their paths/provenance intact, but opt the active release shell into
    # FightStage's existing procedural circle/line impact renderer instead.
    for fx_name in ["fx_hit_jab_01", "fx_hit_power_01", "fx_hit_body_01", "fx_block_01", "fx_counter_flash_01", "fx_knockdown_burst_01"]:
        VisualAssetCatalog._texture_cache["res://assets/visual/v0.7/fx/%s.png" % fx_name] = null

func _v17_top_bar() -> Control:
    var bar := HBoxContainer.new()
    bar.name = "V19TopBar"
    bar.custom_minimum_size.y = 62
    bar.add_theme_constant_override("separation", 8)
    v19_top_bar = bar

    var menu := Button.new()
    menu.name = "V19MenuButton"
    menu.icon = _v18_line_icon("menu")
    menu.flat = true
    menu.custom_minimum_size = Vector2(56, 56)
    menu.tooltip_text = "내 선수"
    menu.pressed.connect(Callable(self, "_v17_open_overlay").bind("profile"))
    bar.add_child(menu)
    v19_menu_button = menu

    var brand := Label.new()
    brand.name = "V19Brand"
    brand.text = "TWELVE COUNT"
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    brand.add_theme_font_override("font", _v18_font(760))
    brand.add_theme_font_size_override("font_size", 20)
    brand.add_theme_color_override("font_color", V17_GOLD)
    bar.add_child(brand)

    var account := VBoxContainer.new()
    account.name = "V19MoneyBox"
    account.custom_minimum_size.x = 70
    account.alignment = BoxContainer.ALIGNMENT_CENTER
    bar.add_child(account)
    v17_money_label = _v17_copy(account, "0원", false)
    v17_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    v17_money_label.add_theme_font_size_override("font_size", 11)
    v19_money_box = account

    var settings := Button.new()
    settings.name = "V19SettingsButton"
    settings.icon = _v18_line_icon("settings")
    settings.flat = true
    settings.custom_minimum_size = Vector2(56, 56)
    settings.disabled = true
    settings.tooltip_text = "설정 준비 중"
    bar.add_child(settings)
    v19_settings_button = settings
    return bar

func _v17_bottom_nav() -> Control:
    var nav := super._v17_bottom_nav()
    nav.name = "V19BottomNav"
    v19_bottom_nav = nav
    return nav

func _v17_sync_nav() -> void:
    super._v17_sync_nav()
    _v19_apply_phase_chrome()

func _v19_apply_phase_chrome() -> void:
    if GameState.state.is_empty():
        return
    var in_fight := str(GameState.state.get("phase", "")) == "fight" and v17_overlay.is_empty()
    if is_instance_valid(v19_bottom_nav):
        v19_bottom_nav.visible = not in_fight
    if is_instance_valid(v19_top_bar):
        v19_top_bar.custom_minimum_size.y = 46 if in_fight else 62
    if is_instance_valid(v19_menu_button):
        v19_menu_button.visible = not in_fight
    if is_instance_valid(v19_money_box):
        v19_money_box.visible = not in_fight
    if is_instance_valid(v19_settings_button):
        v19_settings_button.visible = not in_fight

func _render_tactical_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return

    _v17_section_heading("전술 준비", "이번 상대에게 가져갈 한 가지 흐름을 정합니다. 영구 성장 없이 이번 경기에만 적용됩니다.")
    _v19_tactical_matchup_hero()

    var tactics_heading := HBoxContainer.new()
    tactics_heading.add_theme_constant_override("separation", 8)
    body.add_child(tactics_heading)
    var title := Label.new()
    title.text = "매치업 플랜"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_override("font", _v18_font(700))
    title.add_theme_font_size_override("font_size", 15)
    title.add_theme_color_override("font_color", V17_TEXT)
    tactics_heading.add_child(title)
    var note := Label.new()
    note.text = "1개 선택"
    note.add_theme_font_size_override("font_size", 11)
    note.add_theme_color_override("font_color", V17_MUTED)
    tactics_heading.add_child(note)

    var index := 1
    for prep_value in GameState.tactical_preparations():
        _v19_tactical_row(index, prep_value)
        index += 1

    var back := _v17_secondary_button("← 상대 다시 선택")
    back.pressed.connect(Callable(self, "_return_from_tactical_to_offers"))
    body.add_child(back)
    _configure_mobile_scroll()

func _v19_tactical_matchup_hero() -> void:
    var panel := PanelContainer.new()
    panel.name = "V19TacticalMatchup"
    panel.add_theme_stylebox_override("panel", _v17_box_style(Color("071019"), Color("253242"), 8, 10))
    body.add_child(panel)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    panel.add_child(row)

    var portrait := TextureRect.new()
    portrait.texture = _v17_opponent_texture(current_opponent)
    portrait.custom_minimum_size = Vector2(96, 128)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 3)
    row.add_child(info)

    var eyebrow := Label.new()
    eyebrow.text = "다음 상대"
    eyebrow.add_theme_font_size_override("font_size", 10)
    eyebrow.add_theme_color_override("font_color", V17_GOLD)
    info.add_child(eyebrow)

    _v17_title(info, "%s %s" % [_v17_opponent_name(current_opponent), _v17_flag(_v17_country(current_opponent))], 20)
    var opponent_meta := "%s · %s" % [_style_label(str(current_opponent.get("style", ""))), "#%d" % int(current_opponent.get("rank", 0))]
    _v17_copy(info, opponent_meta, true)

    var divider := HSeparator.new()
    divider.add_theme_constant_override("separation", 4)
    info.add_child(divider)

    var boxer: Dictionary = GameState.state.get("boxer", {})
    var player_name := Label.new()
    player_name.text = "내 선수 · %s" % str(boxer.get("name", "BOXER"))
    player_name.add_theme_font_override("font", _v18_font(650))
    player_name.add_theme_font_size_override("font_size", 12)
    player_name.add_theme_color_override("font_color", V17_TEXT)
    info.add_child(player_name)
    _v17_copy(info, "체중 %.1fkg · 피로 %d%% · 건강 %d%%" % [float(boxer.get("weight_kg", 0.0)), int(boxer.get("fatigue", 0)), int(boxer.get("health", 0))], true)

func _v19_tactical_row(index: int, prep: Dictionary) -> void:
    var panel := PanelContainer.new()
    panel.name = "V19Tactic_%s" % str(prep.get("id", index))
    panel.add_theme_stylebox_override("panel", _v17_box_style(Color("071019"), Color("1d2b3a"), 7, 8))
    body.add_child(panel)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    panel.add_child(row)

    var number := Label.new()
    number.text = "%02d" % index
    number.custom_minimum_size.x = 26
    number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    number.add_theme_font_override("font", _v18_font(700))
    number.add_theme_font_size_override("font_size", 12)
    number.add_theme_color_override("font_color", V17_GOLD)
    row.add_child(number)

    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_theme_constant_override("separation", 1)
    row.add_child(copy)
    _v17_title(copy, str(prep.get("name", "전술")), 16)
    var description := _v17_copy(copy, _v16_one_line(str(prep.get("description", "")), 46), true)
    description.add_theme_font_size_override("font_size", 11)
    var effect := _v17_copy(copy, _v16_tactical_effect(prep), false)
    effect.add_theme_font_size_override("font_size", 10)
    effect.add_theme_color_override("font_color", V17_GOLD)

    var choose := _v17_dark_button("선택")
    choose.custom_minimum_size = Vector2(72, 56)
    choose.add_theme_color_override("font_color", V17_GOLD)
    choose.add_theme_stylebox_override("normal", _v17_box_style(Color("0a141f"), Color("765e34"), 7, 6))
    choose.pressed.connect(Callable(self, "_choose_tactical_preparation").bind(str(prep.get("id", ""))))
    row.add_child(choose)

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    fighter_profile_root = null
    _clear_body()
    _render_status()
    _v19_apply_phase_chrome()
    body.add_theme_constant_override("separation", 5)

    var had_pending_action: bool = not combat.pending_opponent_action.is_empty()
    var telegraph: Dictionary = combat.prepare_exchange()
    if not had_pending_action and not telegraph.is_empty():
        GameState.save_active_fight(combat.export_state())
    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    var exchange_in_round: int = (int(snap.exchange) % int(combat.balance.fight.exchanges_per_round)) + 1

    _v19_round_strip(int(snap.round), exchange_in_round, int(combat.balance.fight.exchanges_per_round))

    var stage := FightStage.new()
    stage.name = "FightStage"
    stage.configure(str(GameState.state.boxer.get("name", "BOXER")), str(current_opponent.get("name", "")), snap, telegraph)
    stage.opponent_style = _v17_visual_style(current_opponent)
    stage.title_fight = bool(current_opponent.get("title_fight", false))
    stage.custom_minimum_size = Vector2(0, 350)
    body.add_child(stage)
    if not animated_exchange.is_empty():
        stage.play_exchange(animated_exchange)

    _v19_corner_hud(snap)

    var last_exchange: Dictionary = snap.get("last_exchange", {})
    if bool(snap.finished):
        GameState.apply_fight_result(str(snap.result), current_opponent, snap)
        var finish := _v17_panel(body, true)
        _v17_title(finish, CombatPresentation.exchange_headline(last_exchange) if not last_exchange.is_empty() else "경기 종료", 22)
        var settle := _v17_gold_button("경기 정산")
        settle.pressed.connect(func(): _render_phase())
        body.add_child(settle)
        _configure_mobile_scroll()
        return

    _v19_tactical_read(telegraph)

    var next_heading := HBoxContainer.new()
    next_heading.add_theme_constant_override("separation", 8)
    body.add_child(next_heading)
    var action_title := Label.new()
    action_title.text = "다음 행동"
    action_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_title.add_theme_font_override("font", _v18_font(700))
    action_title.add_theme_font_size_override("font_size", 14)
    action_title.add_theme_color_override("font_color", V17_TEXT)
    next_heading.add_child(action_title)
    var hint := Label.new()
    hint.text = "금색 테두리 = 게임플랜 적합"
    hint.add_theme_font_size_override("font_size", 9)
    hint.add_theme_color_override("font_color", V17_MUTED)
    next_heading.add_child(hint)

    _v19_action_controls(selected_plan)
    _configure_mobile_scroll()

func _v19_round_strip(round_number: int, exchange_number: int, exchanges_per_round: int) -> void:
    var strip := VBoxContainer.new()
    strip.name = "V19RoundStrip"
    strip.add_theme_constant_override("separation", 4)
    body.add_child(strip)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    strip.add_child(row)

    var round_label := Label.new()
    round_label.text = "ROUND %d / 3" % round_number
    round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    round_label.add_theme_font_override("font", _v18_font(700))
    round_label.add_theme_font_size_override("font_size", 14)
    round_label.add_theme_color_override("font_color", V17_GOLD)
    row.add_child(round_label)

    var exchange_label := Label.new()
    exchange_label.text = "교환 %d / %d" % [exchange_number, exchanges_per_round]
    exchange_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    exchange_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    exchange_label.add_theme_font_size_override("font_size", 12)
    exchange_label.add_theme_color_override("font_color", V17_MUTED)
    row.add_child(exchange_label)

    var seconds := maxi(0, 180 - exchange_number * 12)
    var clock := Label.new()
    clock.text = "%d:%02d" % [int(seconds / 60.0), seconds % 60]
    clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    clock.add_theme_font_override("font", _v18_font(700))
    clock.add_theme_font_size_override("font_size", 15)
    row.add_child(clock)

    var divider := HSeparator.new()
    divider.modulate = Color(0.42, 0.34, 0.20, 0.65)
    strip.add_child(divider)

func _v19_corner_hud(snap: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.name = "V19CornerHUD"
    row.add_theme_constant_override("separation", 10)
    body.add_child(row)

    _v19_corner_meter(row, str(GameState.state.boxer.get("name", "BOXER")), "KR", float(snap.player_hp), float(snap.player_stamina), false)

    var vs := Label.new()
    vs.text = "VS"
    vs.custom_minimum_size.x = 24
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs.add_theme_font_override("font", _v18_font(700))
    vs.add_theme_font_size_override("font_size", 12)
    vs.add_theme_color_override("font_color", V17_GOLD)
    row.add_child(vs)

    _v19_corner_meter(row, _v17_opponent_name(current_opponent), _v17_country(current_opponent), float(snap.opponent_hp), float(snap.opponent_stamina), true)

func _v19_corner_meter(parent: HBoxContainer, name_text: String, country: String, hp: float, stamina: float, right_align: bool) -> void:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 2)
    parent.add_child(box)

    var name := Label.new()
    name.text = "%s %s" % [name_text, _v17_flag(country)]
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_align else HORIZONTAL_ALIGNMENT_LEFT
    name.add_theme_font_override("font", _v18_font(650))
    name.add_theme_font_size_override("font_size", 11)
    name.add_theme_color_override("font_color", V17_TEXT)
    box.add_child(name)
    _v17_meter(box, "HP", hp, V17_HP)
    _v17_meter(box, "STA", stamina, V17_BLUE)

func _v19_tactical_read(telegraph: Dictionary) -> void:
    var panel := PanelContainer.new()
    panel.name = "V19TacticalRead"
    var style := _v17_box_style(Color("06101a"), Color("27384a"), 5, 7)
    style.border_width_left = 3
    style.border_color = Color("b78a43")
    panel.add_theme_stylebox_override("panel", style)
    body.add_child(panel)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    panel.add_child(row)

    var read := VBoxContainer.new()
    read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    read.add_theme_constant_override("separation", 1)
    row.add_child(read)
    var read_title := Label.new()
    read_title.text = "%s  %d%%" % [V19_READ_LABEL, int(telegraph.get("confidence", 0))]
    read_title.add_theme_font_override("font", _v18_font(700))
    read_title.add_theme_font_size_override("font_size", 13)
    read_title.add_theme_color_override("font_color", V17_GOLD)
    read.add_child(read_title)
    var clue := _v17_copy(read, CombatPresentation.telegraph_title(telegraph), false)
    clue.add_theme_font_size_override("font_size", 11)

    var advice := VBoxContainer.new()
    advice.custom_minimum_size.x = 126
    advice.add_theme_constant_override("separation", 1)
    row.add_child(advice)
    var advice_title := Label.new()
    advice_title.text = "코너 조언"
    advice_title.add_theme_font_size_override("font_size", 10)
    advice_title.add_theme_color_override("font_color", V17_MUTED)
    advice.add_child(advice_title)
    var recommendation := _v17_copy(advice, _v17_recommendation(str(telegraph.get("action_id", ""))), false)
    recommendation.add_theme_font_size_override("font_size", 11)

func _v19_action_controls(selected_plan: Dictionary) -> void:
    var wrap := VBoxContainer.new()
    wrap.name = "V19FightActions"
    wrap.add_theme_constant_override("separation", 6)
    body.add_child(wrap)

    var primary := HBoxContainer.new()
    primary.name = "V19ActionRowPrimary"
    primary.add_theme_constant_override("separation", 6)
    wrap.add_child(primary)
    _v19_action_button(primary, "jab", selected_plan)
    _v19_action_button(primary, "power", selected_plan)

    var secondary := HBoxContainer.new()
    secondary.name = "V19ActionRowSecondary"
    secondary.add_theme_constant_override("separation", 6)
    wrap.add_child(secondary)
    _v19_action_button(secondary, "body", selected_plan)
    _v19_action_button(secondary, "guard", selected_plan)

    var counter := _v19_action_button(wrap, "counter", selected_plan)
    counter.name = "V19ActionCounter"

func _v19_action_button(parent: Container, action_id: String, selected_plan: Dictionary) -> Button:
    var action: Dictionary = combat.balance.actions[action_id]
    var stamina := int(action.get("stamina", 0))
    var recommended := bool(selected_plan.get("action_modifiers", {}).has(action_id))
    var stamina_text := "회복 +%d" % abs(stamina) if stamina < 0 else "소모 %d" % stamina

    var button := Button.new()
    button.name = "FightAction_%s" % action_id
    button.text = "%s\n%s" % [_action_label(action_id), stamina_text]
    button.custom_minimum_size = Vector2(0, 56)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.icon = null
    button.add_theme_font_override("font", _v18_font(680))
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", V17_GOLD if recommended else V17_TEXT)
    button.add_theme_stylebox_override("normal", _v17_box_style(Color("07111b"), Color("a47a38") if recommended else Color("263646"), 7, 6))
    button.add_theme_stylebox_override("hover", _v17_box_style(Color("0b1722"), V17_GOLD if recommended else Color("40546a"), 7, 6))
    button.add_theme_stylebox_override("pressed", _v17_box_style(Color("17140c"), V17_GOLD, 7, 6))
    button.pressed.connect(Callable(self, "_choose_fight_action").bind(action_id))
    parent.add_child(button)
    return button
