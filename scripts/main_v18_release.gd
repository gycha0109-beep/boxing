extends "res://scripts/main_v18_release_base.gd"

# v19 real-device UI pass. No generated image assets: this layer only changes
# layout, typography, hierarchy and procedural fight feedback on top of the
# validated v18 release/runtime stack.
const V19_READ_LABEL := "상대 읽기"
const REFERENCE_TRAINING := preload("res://scripts/ui/reference_training_view.gd")
const REFERENCE_UI := preload("res://scripts/ui/reference_ui.gd")
const REFERENCE_OFFERS := preload("res://scripts/ui/reference_offers_view.gd")
const REFERENCE_PREPARATION := preload("res://scripts/ui/reference_preparation_view.gd")

var v19_top_bar: HBoxContainer
var v19_menu_button: Button
var v19_money_box: Control
var v19_settings_button: Button
var v19_bottom_nav: Control
var v19_previous_overlay: String = ""

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
    menu.pressed.connect(_v19_open_menu)
    bar.add_child(menu)
    v19_menu_button = menu

    var brand := TextureRect.new()
    brand.name = "V20BrandLogo"
    brand.texture = preload("res://assets/visual/reference_v1/brand_gold.png")
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    brand.custom_minimum_size.y = 49
    brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    settings.disabled = false
    settings.pressed.connect(_v19_open_settings)
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
    var active := ""
    if v17_overlay == "match_blocked":
        active = "match"
    elif v17_overlay == "training_blocked":
        active = "training"
    elif v17_overlay.is_empty() and str(GameState.state.get("phase", "")) == "equipment_shop":
        active = "shop"
    if not active.is_empty():
        for key in v17_nav_buttons.keys():
            var button: Button = v17_nav_buttons[key]
            var selected := str(key) == active
            button.add_theme_color_override("font_color", V17_GOLD if selected else V17_MUTED)
            button.add_theme_stylebox_override("normal", _v17_nav_style(selected))
            button.add_theme_stylebox_override("pressed", _v17_nav_style(true))
            button.add_theme_stylebox_override("hover", _v17_nav_style(selected))
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
    _render_reference_preparation(true)

func _render_condition_preparation() -> void:
    _render_reference_preparation(false)

func _render_reference_preparation(tactical: bool) -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return

    var view_name := "ReferenceTacticalPrep" if tactical else "ReferenceConditionPrep"
    var previous := body.get_node_or_null(view_name)
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var view := REFERENCE_PREPARATION.new()
    view.name = view_name
    view.is_tactical = tactical
    view.boxer = GameState.state["boxer"]
    view.opponent = current_opponent
    view.boxer_portrait = VisualAssetCatalog.identity_portrait_texture(true)
    view.opponent_portrait = _v17_opponent_texture(current_opponent)
    view.opponent_details = "%s · 랭킹 #%d %s" % [
        _style_label(str(current_opponent.get("style", ""))),
        int(current_opponent.get("rank", 0)),
        _v17_flag(_v17_country(current_opponent)),
    ]
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(900))
    view.bold_font = _v18_font(750)
    var choices: Array = GameState.tactical_preparations() if tactical else GameState.condition_preparations()
    for preparation: Dictionary in choices:
        view.options.append({
            "id": preparation["id"],
            "name": preparation["name"],
            "description": preparation["description"],
            "effect": _reference_tactical_effect(preparation) if tactical else _v16_condition_effect(preparation),
        })
    if tactical:
        view.confirmed.connect(_choose_tactical_preparation)
        view.back_requested.connect(_return_from_tactical_to_offers)
    else:
        var selected_id := str(GameState.state.get("selected_tactical_prep", ""))
        var selected := GameState.preparation_definition("tactical", selected_id)
        view.locked_tactic = str(selected.get("name", ""))
        view.confirmed.connect(func(id: String):
            _choose_condition_preparation(id)
            _reset_reference_scroll()
        )
        view.back_requested.connect(_return_to_tactical_preparation)
    body.add_child(view)
    _reset_reference_scroll()

func _reference_tactical_effect(preparation: Dictionary) -> String:
    var lines: Array[String] = []
    var actions: Dictionary = preparation.get("action_modifiers", {})
    for action: String in actions:
        var effects := REFERENCE_TRAINING.effect_parts(actions[action])
        lines.append("%s · %s" % [_action_label(action), " / ".join(effects)])
    return "\n".join(lines)

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

# Keep real career state distinct from navigation-only panels.
func _render_phase() -> void:
    if v17_overlay in ["match_blocked", "training_blocked"] and not launch_gate_active:
        _clear_body()
        _render_status()
        _v19_render_blocked_tab(v17_overlay)
        _configure_mobile_scroll()
        _v17_sync_nav()
        return
    super._render_phase()

func _v17_open_training() -> void:
    v17_overlay = ""
    var phase := str(GameState.state.get("phase", ""))
    if phase == "equipment_shop":
        _return_from_equipment_shop()
        return
    if phase == "camp":
        _render_phase()
        return
    v17_overlay = "training_blocked"
    _render_phase()

func _v17_open_match() -> void:
    v17_overlay = ""
    var phase := str(GameState.state.get("phase", ""))
    if phase in ["camp", "equipment_shop", "style_select", "talent_reveal"]:
        v17_overlay = "match_blocked"
    _render_phase()

func _v17_open_shop() -> void:
    v17_overlay = ""
    var phase := str(GameState.state.get("phase", ""))
    if phase == "camp":
        _open_equipment_shop()
        return
    if phase == "equipment_shop":
        _render_phase()
        return
    v17_overlay = "shop"
    _render_phase()

func _v19_return_to_phase() -> void:
    v17_overlay = ""
    _render_phase()

func _v19_render_blocked_tab(tab_id: String) -> void:
    var phase := str(GameState.state.get("phase", ""))
    var panel: VBoxContainer
    if tab_id == "match_blocked":
        _v17_section_heading("경기", "현재 커리어의 진행 순서를 안내합니다.")
        panel = _v17_panel(body, false)
        if phase == "equipment_shop":
            _v17_title(panel, "장비 투자 단계입니다", 22)
            _v17_copy(panel, "장비 구매는 선택 사항입니다. 구매하거나 캠프로 돌아가 훈련을 진행한 다음 경기에 도전할 수 있습니다.", true)
        elif phase == "camp":
            _v17_title(panel, "경기 준비 중", 22)
            _v17_copy(panel, "캠프에서 훈련 또는 회복을 선택하면 경기 계약 단계로 진행합니다.", true)
        else:
            _v17_title(panel, "선수 생성 진행 중", 22)
            _v17_copy(panel, "선수의 스타일과 재능을 확정하면 경기 준비를 시작할 수 있습니다.", true)
    else:
        _v17_section_heading("훈련", "현재 커리어의 진행 순서를 안내합니다.")
        panel = _v17_panel(body, false)
        _v17_title(panel, "현재는 훈련 단계가 아닙니다", 22)
        _v17_copy(panel, "경기 일정과 결과를 진행하면 다음 훈련 캠프가 열립니다. 현재 단계는 유지됩니다.", true)
        if phase == "fight_offer":
            _render_camp_result(body)
            _reset_reference_scroll()
    if phase == "equipment_shop":
        _v19_menu_button(panel, "훈련 캠프로 돌아가기", Callable(self, "_return_from_equipment_shop"))
    _v19_menu_button(panel, "현재 단계로 돌아가기", Callable(self, "_v19_return_to_phase"))

# Browser-preview navigation: make both header icons actionable.
func _v19_open_menu() -> void:
    v19_previous_overlay = v17_overlay
    v17_overlay = ""
    _clear_body()
    _v17_section_heading("메뉴", "이동할 화면을 선택하세요.")
    var panel := _v17_panel(body, false)
    _v19_menu_button(panel, "내 선수", Callable(self, "_v17_open_overlay").bind("profile"))
    _v19_menu_button(panel, "경기 진행", Callable(self, "_v17_open_match"))
    _v19_menu_button(panel, "훈련", Callable(self, "_v17_open_training"))
    _v19_menu_button(panel, "커리어", Callable(self, "_v17_open_overlay").bind("career"))
    _v19_menu_button(panel, "상점", Callable(self, "_v17_open_shop"))
    _v19_menu_button(panel, "닫기", Callable(self, "_v19_close_secondary"))
    _v17_sync_nav()

func _v19_open_settings() -> void:
    v19_previous_overlay = v17_overlay
    v17_overlay = ""
    _clear_body()
    _v17_section_heading("설정", "게임 실행 옵션")
    var panel := _v17_panel(body, false)
    var mute := CheckButton.new()
    mute.text = "모든 게임 소리 끄기"
    mute.button_pressed = AudioServer.is_bus_mute(0)
    mute.toggled.connect(func(value: bool): AudioServer.set_bus_mute(0, value))
    panel.add_child(mute)
    _v19_menu_button(panel, "게임으로 돌아가기", Callable(self, "_v19_close_secondary"))
    _v17_sync_nav()

func _v19_menu_button(parent: Node, label_text: String, action: Callable) -> void:
    var btn := Button.new()
    btn.text = label_text
    btn.custom_minimum_size = Vector2(0, 54)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.pressed.connect(action)
    parent.add_child(btn)

func _v19_close_secondary() -> void:
    v17_overlay = v19_previous_overlay
    _render_phase()

# Reference-accurate boxer profile; other tabs keep their validated flow.
func _v17_render_profile_home() -> void:
    var profile_view := preload("res://scripts/ui/reference_profile_view.gd").new()
    body.add_child(profile_view)

# Shared embossed gold navigation treatment from the user reference.
func _v17_nav_style(selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#241b12") if selected else Color("#0b1827")
    style.border_color = Color("#e8bb70") if selected else Color("#516070")
    style.set_border_width_all(2 if selected else 1)
    style.set_corner_radius_all(7)
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    style.content_margin_left = 1
    style.content_margin_right = 1
    style.shadow_size = 4 if selected else 1
    style.shadow_color = Color(0.77, 0.48, 0.11, 0.24) if selected else Color(0, 0, 0, 0.35)
    return style

# The reference-driven camp uses the existing career actions and transition logic.
func _render_camp() -> void:
    var training := REFERENCE_TRAINING.new()
    training.actions = camp_actions
    training.bold_font = _v18_font(750)
    training.heading_font = REFERENCE_UI.heading_font(_v18_font(900))
    training.action_chosen.connect(_choose_camp_action)
    training.shop_requested.connect(_open_equipment_shop)
    body.add_child(training)
    _reset_reference_scroll()

func _choose_camp_action(action: Dictionary) -> void:
    var before: Dictionary = GameState.state["boxer"].duplicate(true)
    var applied := GameState.apply_camp_action(action)
    if not bool(applied.get("ok", false)):
        return

    # Measure the final change, including caps, traits, equipment and legacy effects.
    var after: Dictionary = GameState.state["boxer"]
    var changes := {}
    for key in REFERENCE_TRAINING.STAT_LABELS:
        if key == "injury_camps":
            continue
        var boxer_key: String = "weight_kg" if key == "weight" else key
        var delta := float(after[boxer_key]) - float(before[boxer_key])
        if not is_zero_approx(delta):
            changes[key] = delta
    var injury_before: Dictionary = before.get("injury", {})
    var injury_after: Dictionary = after.get("injury", {})
    var injury_message := ""
    if injury_before != injury_after:
        if injury_after.is_empty():
            injury_message = "부상 회복"
        else:
            injury_message = "부상 · %s (남은 기간 %d캠프)" % [
                str(injury_after.get("name", "")), int(injury_after.get("remaining_camps", 0)),
            ]

    GameState.state["last_camp_result"] = {
        "action_id": str(action["id"]),
        "changes": changes,
        "injury": injury_message,
    }
    SaveService.save_game(GameState.state)
    _render_phase()
    _reset_reference_scroll()

func _reset_reference_scroll() -> void:
    var scroll := find_child("V17ContentScroll", true, false) as ScrollContainer
    if scroll != null:
        scroll.set_deferred("scroll_vertical", 0)

func _render_offers() -> void:
    var previous := body.get_node_or_null("ReferenceFightOffers")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var view := REFERENCE_OFFERS.new()
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(900))
    view.bold_font = _v18_font(750)
    for opponent: Dictionary in GameState.get_fight_offers(opponents):
        view.offers.append({
            "opponent": opponent,
            "portrait": _v17_opponent_texture(opponent),
            "style": _style_label(str(opponent.get("style", ""))),
            "country": _v17_country(opponent),
            "purse": _v17_money(int(opponent.get("purse", 0))),
        })
    view.opponent_chosen.connect(_accept_reference_offer)
    body.add_child(view)
    var result := _render_camp_result(view, true)
    if result != null:
        view.move_child(result.get_parent(), 1)
    _v17_career_progress_strip()
    _reset_reference_scroll()

func _accept_reference_offer(opponent: Dictionary) -> void:
    if str(GameState.state.get("phase", "")) != "fight_offer" or not v17_overlay.is_empty():
        return
    _choose_opponent(opponent)
    _reset_reference_scroll()

func _render_camp_result(parent: Container, compact: bool = false) -> VBoxContainer:
    # Older saves can have a choice without a recorded change.
    var result: Dictionary = GameState.state.get("last_camp_result", {})
    var action_id := str(GameState.state.get("last_camp_action", ""))
    if result.is_empty() or str(result.get("action_id", "")) != action_id:
        return null
    for action: Dictionary in camp_actions:
        if str(action.get("id", "")) != action_id:
            continue
        var panel := _v17_panel(parent, true)
        panel.name = "TrainingResult"
        if compact:
            (panel.get_parent() as PanelContainer).add_theme_stylebox_override(
                "panel", _v17_box_style(V17_PANEL_2, V17_GOLD, 6, 6),
            )
            panel.add_theme_constant_override("separation", 2)
        _v17_title(panel, "훈련 결과 · " + REFERENCE_TRAINING.action_title(action), 17)
        var parts := REFERENCE_TRAINING.effect_parts(result.get("changes", {}))
        var injury := str(result.get("injury", ""))
        if not injury.is_empty():
            parts.append(injury)
        _v17_copy(panel, "변화 없음" if parts.is_empty() else " · ".join(parts), true)
        var boxer: Dictionary = GameState.state["boxer"]
        _v17_copy(panel, "현재 건강 %d / 100   ·   피로 %d / 100" % [int(boxer["health"]), int(boxer["fatigue"])], true)
        return panel
    return null
