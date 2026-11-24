extends "res://scripts/main_v18_release_base.gd"

# v19 real-device UI pass. No generated image assets: this layer only changes
# layout, typography, hierarchy and procedural fight feedback on top of the
# validated v18 release/runtime stack.
const REFERENCE_TRAINING := preload("res://scripts/ui/reference_training_view.gd")
const REFERENCE_UI := preload("res://scripts/ui/reference_ui.gd")
const REFERENCE_OFFERS := preload("res://scripts/ui/reference_offers_view.gd")
const REFERENCE_PREPARATION := preload("res://scripts/ui/reference_preparation_view.gd")
const REFERENCE_PREFIGHT := preload("res://scripts/ui/reference_prefight_view.gd")
const REFERENCE_BATTLE := preload("res://scripts/ui/reference_battle_view.gd")
const REFERENCE_RESULT := preload("res://scripts/ui/reference_result_view.gd")
const REFERENCE_LEGACY := preload("res://scripts/ui/reference_legacy_view.gd")
const REFERENCE_TITLE := preload("res://scripts/ui/reference_title_view.gd")
const TWELVE_DESIGN := preload("res://scripts/ui/twelve_design_system.gd")
const REFERENCE_CREATION := preload("res://scripts/ui/reference_creation_view.gd")
const REFERENCE_EVENT := preload("res://scripts/ui/reference_career_event_view.gd")
const REFERENCE_EQUIPMENT := preload("res://scripts/ui/reference_equipment_shop.gd")
const REFERENCE_CAREER := preload("res://scripts/ui/reference_career_record.gd")
const REFERENCE_HOME := preload("res://scripts/ui/reference_home_view.gd")
const REFERENCE_MATCHUP := preload("res://scripts/ui/reference_matchup_view.gd")
const FIRST_BOUT_GUIDE_SETTINGS := "user://first_bout_guide.cfg"
const INSTALL_ONBOARDING_SETTINGS := "user://onboarding_install.cfg"
# Disabled unless explicitly enabled in project.godot for internal preview builds.
const DEV_RESET_SETTING := "application/config/dev_reset_enabled"
const FIRST_CYCLE_STORY := preload("res://scripts/ui/first_cycle_story_view.gd")
const FIRST_CYCLE_SPOTLIGHT := preload("res://scripts/ui/first_cycle_spotlight.gd")
const FIRST_CYCLE_TALENT_ROLL := preload("res://scripts/ui/first_cycle_talent_roll.gd")

var v19_top_bar: HBoxContainer
var v19_menu_button: Button
var v19_money_box: Control
var v19_settings_button: Button
var _dev_reset_confirmation: ConfirmationDialog
var _onboarding_install := ConfigFile.new()
var v19_bottom_nav: Control
var v19_previous_overlay: String = ""
var _equipment_section := "personal"
var _equipment_receipt: Dictionary
var _guide_settings := ConfigFile.new()
var _dev_live_refresh_button: Button
var _dev_ui_refresh_count := 0

func _ready() -> void:
    theme = TWELVE_DESIGN.theme_for_game()
    _guide_settings.load(FIRST_BOUT_GUIDE_SETTINGS)
    _onboarding_install.load(INSTALL_ONBOARDING_SETTINGS)
    # An existing career is an existing installation even if this marker was
    # introduced by an update. Fresh installs use the bootstrapped placeholder
    # career with first_launch_acknowledged == false.
    if not bool(_onboarding_install.get_value("install", "tutorial_started", false)):
        if bool(GameState.state.get("first_launch_acknowledged", false)):
            _mark_onboarding_started()
    _v19_disable_legacy_bitmap_fx()
    super._ready()
    _v19_apply_phase_chrome()
    _install_dev_reset_confirmation()
    _install_dev_live_refresh_button()

func _install_dev_live_refresh_button() -> void:
    if not _dev_reset_enabled() or is_instance_valid(_dev_live_refresh_button):
        return
    _dev_live_refresh_button = Button.new()
    _dev_live_refresh_button.name = "DevLiveUIRefreshButton"
    _dev_live_refresh_button.text = "UI 갱신"
    _dev_live_refresh_button.tooltip_text = "현재 게임 상태를 유지하고 화면만 다시 구성합니다."
    _dev_live_refresh_button.position = Vector2(8, 8)
    _dev_live_refresh_button.size = Vector2(104, 34)
    _dev_live_refresh_button.z_index = 1000
    _dev_live_refresh_button.focus_mode = Control.FOCUS_NONE
    var refresh_style := StyleBoxFlat.new()
    refresh_style.bg_color = Color("#172331")
    refresh_style.border_color = Color("#d5a94d")
    refresh_style.set_border_width_all(1)
    refresh_style.set_corner_radius_all(5)
    _dev_live_refresh_button.add_theme_stylebox_override("normal", refresh_style)
    _dev_live_refresh_button.add_theme_stylebox_override("hover", refresh_style)
    _dev_live_refresh_button.add_theme_color_override("font_color", Color("#f4d58a"))
    _dev_live_refresh_button.pressed.connect(_dev_refresh_button_pressed)
    add_child(_dev_live_refresh_button)

func _dev_refresh_button_pressed() -> void:
    if is_instance_valid(_dev_live_refresh_button):
        _dev_live_refresh_button.text = "갱신 중..."
    _dev_refresh_current_ui()

# Editor-only live UI workflow:
# Godot Debug > Synchronize Script Changes reloads externally edited GDScripts.
# Press F8 afterward to rebuild the current screen from the unchanged GameState.
var _dev_ui_refresh_pending := false
var _dev_ui_restore_scroll := 0

func _unhandled_key_input(event: InputEvent) -> void:
    if not _dev_reset_enabled():
        return
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo or key.keycode != KEY_F8:
        return
    # F8 is Godot's Stop shortcut; require Ctrl+Shift to avoid editor interception.
    if not key.ctrl_pressed or not key.shift_pressed:
        return
    get_viewport().set_input_as_handled()
    if _dev_ui_refresh_pending:
        return
    call_deferred("_dev_refresh_current_ui")

func _dev_refresh_current_ui() -> void:
    if not _dev_reset_enabled() or not is_inside_tree() or _dev_ui_refresh_pending:
        return
    _dev_ui_refresh_pending = true
    var scroll := find_child("V17ContentScroll", true, false) as ScrollContainer
    _dev_ui_restore_scroll = scroll.scroll_vertical if scroll != null else 0
    # Rebuild only the visible UI. GameState, save data, opponent selection,
    # combat state, currency, and career progress are deliberately untouched.
    _render_phase()
    call_deferred("_dev_restore_ui_scroll")

func _dev_restore_ui_scroll() -> void:
    await get_tree().process_frame
    var scroll := find_child("V17ContentScroll", true, false) as ScrollContainer
    if scroll != null:
        scroll.scroll_vertical = mini(_dev_ui_restore_scroll, int(scroll.get_v_scroll_bar().max_value))
    _dev_ui_refresh_pending = false
    _dev_ui_refresh_count += 1
    if is_instance_valid(_dev_live_refresh_button):
        _dev_live_refresh_button.text = "갱신 완료 #%d" % _dev_ui_refresh_count
    print("[LIVE UI] Current screen rebuilt from existing game state. Count=%d" % _dev_ui_refresh_count)

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
    menu.custom_minimum_size = Vector2.ZERO
    menu.visible = false
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
    var nav := PanelContainer.new()
    nav.name = "V19BottomNav"
    nav.custom_minimum_size = Vector2(0, 74)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#07121e")
    style.border_color = Color("#8d6c3c")
    style.border_width_top = 1
    style.content_margin_top = 3
    style.content_margin_left = 2
    style.content_margin_right = 2
    nav.add_theme_stylebox_override("panel", style)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 2)
    nav.add_child(row)
    v17_nav_buttons.clear()
    _v17_nav_button(row, "home", "⌂\n홈", Callable(self, "_v19_open_home"))
    _v17_nav_button(row, "profile", "♟\n복서", Callable(self, "_v17_open_overlay").bind("profile"))
    _v17_nav_button(row, "training", "▤\n훈련 계획", Callable(self, "_v17_open_training"))
    _v17_nav_button(row, "schedule", "▦\n일정", Callable(self, "_v19_open_schedule"))
    _v17_nav_button(row, "ranking", "♜\n랭킹", Callable(self, "_v17_open_overlay").bind("career"))
    _v17_nav_button(row, "management", "▣\n매니지먼트", Callable(self, "_v17_open_shop"))
    v19_bottom_nav = nav
    return nav

func _v17_sync_nav() -> void:
    call_deferred("_apply_twelve_design_finish")
    var active := "schedule"
    if v17_overlay == "home":
        active = "home"
    elif v17_overlay == "profile":
        active = "profile"
    elif v17_overlay == "career":
        active = "ranking"
    elif v17_overlay == "shop" or str(GameState.state.get("phase", "")) == "equipment_shop":
        active = "management"
    elif v17_overlay == "training_blocked":
        active = "training"
    elif v17_overlay == "match_blocked" or v17_overlay == "schedule":
        active = "schedule"
    elif v17_overlay.is_empty():
        var phase := str(GameState.state.get("phase", ""))
        if phase in ["camp", "style_select", "talent_reveal", "gym_fund_intro"]:
            active = "training"
        elif phase in ["fight_offer", "tactical_prep", "condition_prep", "game_plan", "fight", "result", "season_review", "champion_choice", "sponsor_offer"]:
            active = "schedule"
    for key in v17_nav_buttons.keys():
        var button: Button = v17_nav_buttons[key]
        var selected := str(key) == active
        button.add_theme_color_override("font_color", V17_GOLD if selected else V17_MUTED)
        button.add_theme_stylebox_override("normal", _v17_nav_style(selected))
        button.add_theme_stylebox_override("pressed", _v17_nav_style(true))
        button.add_theme_stylebox_override("hover", _v17_nav_style(selected))
    _v19_apply_phase_chrome()

func _apply_twelve_design_finish() -> void:
    if not is_inside_tree() or launch_gate_active:
        return
    TWELVE_DESIGN.polish_tree(self)

func _v19_apply_phase_chrome() -> void:
    if GameState.state.is_empty():
        return
    var in_fight := not launch_gate_active and str(GameState.state.get("phase", "")) == "fight" and v17_overlay.is_empty()
    var in_story := _tutorial_special_screen()
    var guided := _tutorial_active()
    if is_instance_valid(v19_bottom_nav):
        v19_bottom_nav.visible = not in_fight and not launch_gate_active and not in_story and not guided
    if is_instance_valid(v19_top_bar):
        v19_top_bar.visible = not launch_gate_active and (not in_story or _dev_reset_enabled())
        v19_top_bar.custom_minimum_size.y = 46 if in_fight else 62
    if is_instance_valid(v19_menu_button):
        v19_menu_button.visible = false
    if is_instance_valid(v19_money_box):
        v19_money_box.visible = not in_fight and not guided
    if is_instance_valid(v19_settings_button):
        v19_settings_button.visible = not in_fight or _dev_reset_enabled()

func _render_game_plan() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        super._render_game_plan()
        return
    var view := REFERENCE_MATCHUP.new()
    var player_data: Dictionary = GameState.state.get("boxer", {}).duplicate(true)
    var career: Dictionary = GameState.state.get("career", {})
    player_data["rank"] = int(career.get("rank", 0))
    view.player = player_data
    view.career = career
    view.opponent = current_opponent.duplicate(true)
    view.plans = GameState.game_plans
    view.suggested_plans = current_opponent.get("scouting", {}).get("suggested_plans", [])
    view.plan_effects = {}
    for plan_value in GameState.game_plans:
        var plan: Dictionary = plan_value
        view.plan_effects[str(plan.get("id", ""))] = _plan_effect_text(plan)
    var current_plan: Dictionary = GameState.get_selected_game_plan()
    view.selected_plan_id = str(current_plan.get("id", ""))
    view.player_texture = VisualAssetCatalog.identity_portrait_texture(true)
    view.opponent_texture = _v17_opponent_texture(current_opponent)
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.money_text = Callable(self, "_v17_money")
    view.plan_confirmed.connect(_choose_game_plan, CONNECT_DEFERRED)
    view.offers_requested.connect(_return_to_fight_offers, CONNECT_DEFERRED)
    view.condition_requested.connect(_return_to_condition_preparation, CONNECT_DEFERRED)
    body.add_child(view)
    _reset_reference_scroll()

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
    view.tutorial_mode = _tutorial_active()
    if tactical and view.tutorial_mode:
        var suggested: Array = current_opponent.get("scouting", {}).get("suggested_plans", [])
        for plan_id in ["counter_trap", "outside_boxing", "body_breakdown", "pressure"]:
            if suggested.has(plan_id):
                view.recommended_tactic_id = str({
                    "counter_trap": "counter_timing",
                    "outside_boxing": "distance_drill",
                    "body_breakdown": "body_pattern",
                    "pressure": "pressure_entry",
                }[plan_id])
                break
    view.boxer = GameState.state["boxer"]
    if _tutorial_active():
        if tactical:
            var scouting: Dictionary = current_opponent.get("scouting", {})
            view.guide_tip = "강점: %s\n약점: %s\n주의할 버릇: %s\n상대가 강한 행동을 피하고 약점을 겨냥하는 전술을 고르세요." % [
                str(scouting.get("strength", "확인 중")), str(scouting.get("weakness", "확인 중")), str(scouting.get("tell", "확인 중"))]
        else:
            var limit := float(GameState.career_balance["weight_class"]["limit_kg"])
            if float(view.boxer.get("weight_kg", 0.0)) > limit:
                view.guide_tip = "계체 기준 %.1fkg을 넘었습니다. 체중 조절 효과를 확인하세요." % limit
            else:
                view.guide_tip = "계체 기준 %.1fkg 이내입니다. 피로를 보고 컨디션을 준비하세요." % limit
    view.opponent = current_opponent
    view.boxer_portrait = VisualAssetCatalog.identity_portrait_texture(true)
    view.opponent_portrait = _v17_opponent_texture(current_opponent)
    view.opponent_details = "%s · 랭킹 #%d %s" % [
        _style_label(str(current_opponent.get("style", ""))),
        int(current_opponent.get("rank", 0)),
        _v17_flag(_v17_country(current_opponent)),
    ]
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
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
        view.tutorial_skipped.connect(_skip_first_bout_guide)
    else:
        var selected_id := str(GameState.state.get("selected_tactical_prep", ""))
        var selected := GameState.preparation_definition("tactical", selected_id)
        view.locked_tactic = str(selected.get("name", ""))
        view.confirmed.connect(func(id: String):
            _choose_condition_preparation(id)
            _reset_reference_scroll()
        )
        view.back_requested.connect(_return_to_tactical_preparation)
        view.tutorial_skipped.connect(_skip_first_bout_guide)
    body.add_child(view)
    _reset_reference_scroll()

func _reference_tactical_effect(preparation: Dictionary) -> String:
    var lines: Array[String] = []
    var actions: Dictionary = preparation.get("action_modifiers", {})
    for action: String in actions:
        var effects := REFERENCE_TRAINING.effect_parts(actions[action])
        lines.append("%s · %s" % [_action_label(action), " / ".join(effects)])
    return "\n".join(lines)

func _render_game_plan_legacy() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        super._render_game_plan()
        return

    var view := _new_prefight_view("ReferenceScouting")
    var scouting: Dictionary = current_opponent.get("scouting", {})
    view.difficulty = str(REFERENCE_UI.DIFFICULTY.get(current_opponent.get("difficulty", ""), "미정"))
    view.opponent_country = _v17_flag(_v17_country(current_opponent))
    view.opponent_details = "%s  ·  랭킹 #%d" % [_style_label(str(current_opponent.get("style", ""))), int(current_opponent["rank"])]
    view.analysis = scouting
    view.tutorial_mode = _tutorial_active()
    view.tendencies = current_opponent.get("tendencies", {})
    var opponent_stats: Dictionary = current_opponent.get("stats", {})
    var fight_boxer := GameState.get_fight_boxer()
    for id: String in ["power", "speed", "technique", "defense", "conditioning"]:
        view.comparison.append({
            "name": REFERENCE_TRAINING.STAT_LABELS[id],
            "player": int(fight_boxer.get(id, 0)),
            "opponent": int(opponent_stats.get(id, 0)),
        })
    var recommended: Array = scouting.get("suggested_plans", [])
    for plan: Dictionary in GameState.game_plans:
        var entry := plan.duplicate()
        entry["recommended"] = str(plan["id"]) in recommended
        entry["effect"] = _plan_effect_text(plan)
        view.plans.append(entry)
    view.plan_chosen.connect(_choose_game_plan)
    view.opponent_back_requested.connect(_return_to_fight_offers)
    view.tutorial_skipped.connect(_skip_first_bout_guide)
    body.add_child(view)
    _reset_reference_scroll()

func _render_weigh_in() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        super._render_weigh_in()
        return

    _clear_body()
    _render_status()
    var view := _new_prefight_view("ReferenceWeighIn")
    view.tutorial_mode = _tutorial_active()
    view.weighing = true
    view.weight_class = GameState.career_balance["weight_class"]
    view.weigh = _weigh_in_presentation()
    view.confirmed_plan = GameState.get_selected_game_plan()
    view.allow_plan_back = not GameState.state.get("pre_game_plan_snapshot", {}).is_empty()
    view.back_requested.connect(_return_to_game_plan_selection)
    view.fight_requested.connect(_acknowledge_weigh_in)
    view.tutorial_skipped.connect(_skip_first_bout_guide)
    body.add_child(view)
    _configure_mobile_scroll()
    _reset_reference_scroll()

func _new_prefight_view(view_name: String) -> VBoxContainer:
    var previous := body.get_node_or_null(view_name)
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var view := REFERENCE_PREFIGHT.new()
    view.name = view_name
    view.player = GameState.state["boxer"]
    view.opponent = current_opponent
    view.player_photo = VisualAssetCatalog.identity_portrait_texture(true)
    view.opponent_photo = _v17_opponent_texture(current_opponent)
    view.opponent_details = "%s · 랭킹 #%d %s" % [
        _style_label(str(current_opponent.get("style", ""))),
        int(current_opponent.get("rank", 0)),
        _v17_flag(_v17_country(current_opponent)),
    ]
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    return view

func _weigh_in_presentation() -> Dictionary:
    var result: Dictionary = GameState.state.get("last_weigh_in", {})
    var previous: Dictionary = GameState.state.get("pre_game_plan_snapshot", {})
    var boxer: Dictionary = GameState.state["boxer"]
    var over := maxf(0.0, float(result.get("over_kg", 0.0)))
    match str(result.get("status", "")):
        "pass":
            return {"label": "계체 통과", "color": Color("#8ae69d"), "detail": "체중 제한을 충족했습니다. 경기에 입장할 수 있습니다."}
        "emergency_cut":
            var detail := "제한을 %.2f kg 초과해 긴급 감량을 적용했습니다." % over
            if previous.has("health") and previous.has("fatigue"):
                detail += " 건강 %+d · 피로 %+d" % [
                    int(boxer["health"]) - int(previous["health"]),
                    int(boxer["fatigue"]) - int(previous["fatigue"]),
                ]
            return {"label": "긴급 감량 통과", "color": REFERENCE_UI.GOLD, "detail": detail}
        "miss":
            var purse := roundi(float(result.get("purse_multiplier", 1.0)) * 100.0)
            var detail := "제한을 %.2f kg 초과했습니다. 계약 파이트머니의 %d%%가 적용됩니다." % [over, purse]
            if previous.has("reputation"):
                var difference := int(GameState.state.career.reputation) - int(previous["reputation"])
                if difference < 0:
                    detail += " 평판 %d" % difference
            return {"label": "계체 실패", "color": Color("#e2766d"), "detail": detail}
    return {"label": "계체 결과 미기록", "color": V17_MUTED, "detail": "현재 경기와 확정된 게임플랜을 확인하세요."}

func _configure_mobile_scroll() -> void:
    super._configure_mobile_scroll()
    if _needs_weigh_in_interstitial():
        var scroll := find_child("V17ContentScroll", true, false) as ScrollContainer
        if scroll != null:
            scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    # Fight HUD manages its own guide. A spotlight from preparation must
    # never linger over the fight buttons or the end-of-round UI.
    var old_spotlight := get_node_or_null("FirstCycleSpotlight")
    if old_spotlight != null:
        remove_child(old_spotlight)
        old_spotlight.queue_free()
    fighter_profile_root = null
    _clear_body()
    var previous := body.get_node_or_null("ReferenceBattle")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    _render_status()
    _v19_apply_phase_chrome()

    if _tutorial_active() and int(GameState.state.get("career", {}).get("fights", 0)) == 0:
        combat.tutorial_first_bout = true
    var had_pending_action: bool = not combat.pending_opponent_action.is_empty()
    var telegraph: Dictionary = combat.prepare_exchange()
    if not had_pending_action and not telegraph.is_empty():
        GameState.save_active_fight(combat.export_state())
    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    var boxer: Dictionary = GameState.state["boxer"]

    var stage := FightStage.new()
    stage.close_up = true
    stage.clip_contents = true
    stage.custom_minimum_size.y = 320.0 if _tutorial_active() else 395.0
    stage.configure(str(boxer.get("name", "")), str(current_opponent.get("name", "")), snap, telegraph)
    stage.opponent_style = _v17_visual_style(current_opponent)
    stage.title_fight = bool(current_opponent.get("title_fight", false))

    var view := REFERENCE_BATTLE.new()
    view.name = "ReferenceBattle"
    view.stage = stage
    view.snapshot = snap
    view.telegraph = telegraph
    view.show_first_exchange_guide = false
    if _tutorial_active():
        view.tutorial_target_action = _tutorial_next_action()
        if not view.tutorial_target_action.is_empty():
            var action_labels := {"jab": "잽", "guard": "가드", "body": "바디", "power": "파워", "counter": "카운터"}
            view.tutorial_hint = "첫 경기 9/10 · %s 버튼을 눌러보고 상대의 반응과 체력을 확인하세요." % str(action_labels.get(view.tutorial_target_action, ""))
        else:
            view.tutorial_hint = "첫 경기 9/10 · 잽·가드·카운터를 익혔습니다. 이제 자유롭게 경기를 마치세요."
    view.player_name = str(boxer.get("name", "무명 복서"))
    view.player_style = str(boxer.get("identity_name", "균형형"))
    view.player_trait = str(boxer.get("trait_name", ""))
    view.player_rank = int(GameState.state["career"].get("rank", 0))
    view.opponent_rank = int(current_opponent.get("rank", 0))
    view.opponent_name = ("%s %s" % [_v17_opponent_name(current_opponent), _v17_flag(_v17_country(current_opponent))]).strip_edges()
    view.opponent_style = _style_label(str(current_opponent.get("style", "")))
    view.round_count = int(combat.balance.fight.rounds)
    view.exchanges_per_round = int(combat.balance.fight.exchanges_per_round)
    var exchange_index := maxi(0, int(snap["exchange"]) - (1 if bool(snap["finished"]) else 0))
    view.exchange_in_round = exchange_index % view.exchanges_per_round + 1
    view.weight_class = str(GameState.career_balance["weight_class"]["name"])
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.advice = _v17_recommendation(str(telegraph.get("action_id", "")))
    for id: String in ["jab", "power", "body", "guard", "counter"]:
        view.actions.append({
            "id": id,
            "label": _action_label(id),
            "stamina": int(combat.balance.actions[id]["stamina"]),
            "recommended": selected_plan.get("action_modifiers", {}).has(id),
        })
    view.action_chosen.connect(_choose_fight_action)
    view.tutorial_skipped.connect(_skip_first_bout_guide)
    view.settlement_requested.connect(_render_phase)
    body.add_child(view)
    if not animated_exchange.is_empty():
        stage.play_exchange(animated_exchange)
    if bool(snap["finished"]) and str(GameState.state.get("phase", "")) == "fight":
        GameState.apply_fight_result(str(snap["result"]), current_opponent, snap)
    _configure_mobile_scroll()

func _render_result() -> void:
    var previous := body.get_node_or_null("ReferenceFightResult")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var summary: Dictionary = GameState.state.get("last_fight_summary", {})
    var boxer: Dictionary = GameState.state["boxer"]
    var injury: Dictionary = boxer.get("injury", {})
    var opponent: Dictionary = _find_opponent(str(summary.get("opponent_id", "")))
    var view := REFERENCE_RESULT.new()
    view.name = "ReferenceFightResult"
    view.summary = summary
    view.boxer = boxer
    view.career = GameState.state["career"]
    view.result_id = str(summary.get("result", GameState.state.get("last_result", "")))
    view.result_text = _result_label(view.result_id) if not view.result_id.is_empty() else "경기 종료"
    view.opponent_name = str(summary.get("opponent_name", "상대 선수"))
    if not opponent.is_empty():
        view.opponent_name += " " + _v17_flag(_v17_country(opponent))
        view.opponent_portrait = _v17_opponent_texture(opponent)
    view.weight_class = str(GameState.career_balance["weight_class"]["name"])
    var plan := GameState.get_game_plan(str(summary.get("game_plan", "balanced")))
    view.plan_name = str(plan.get("name", "균형 운영"))
    view.injury_text = str(injury.get("name", ""))
    view.show_first_settlement_guide = false
    view.money_text = _v17_money
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    if int(GameState.state.career.fights) == 12 and GameState.state.career_state.has("milestone"):
        _review_panel("12전 커리어 평가", GameState.state.career_state.milestone)
    view.continue_requested.connect(_continue_from_reference_result)
    body.add_child(view)
    if str(summary.get("title_won", "")) == "district":
        _v17_section_heading("구·시 챔피언 등극!", "결과를 확인하면 첫 공식 스폰서의 제안을 받을 수 있습니다.")
    _reset_reference_scroll()

func _continue_from_reference_result() -> void:
    if str(GameState.state.get("phase", "")) != "result":
        return
    if _tutorial_active() and int(GameState.state.get("career", {}).get("fights", 0)) == 1:
        var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
        tutorial["complete"] = true
        tutorial["active"] = false
        tutorial["complete_pending"] = true
        GameState.state["first_cycle_tutorial"] = tutorial
        SaveService.save_game(GameState.state)
    GameState.advance_after_result()
    current_opponent = {}
    _render_phase()
    _reset_reference_scroll()

func _render_event() -> void:
    var previous := body.get_node_or_null("ReferenceCareerEvent")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var state: Dictionary = GameState.state
    var event: Dictionary = state.get("pending_event", {})
    if event.is_empty():
        _continue_from_reference_event()
        return
    var view := REFERENCE_EVENT.new()
    view.name = "ReferenceCareerEvent"
    view.event = event
    view.before = {"boxer": state["boxer"], "career": state["career"]}
    view.projected = GameState.project_pending_event()
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.money_text = _v17_money
    view.continue_requested.connect(_continue_from_reference_event, CONNECT_DEFERRED)
    body.add_child(view)
    _reset_reference_scroll()

func _continue_from_reference_event() -> void:
    if str(GameState.state.get("phase", "")) != "event":
        return
    GameState.resolve_pending_event()
    _render_phase()
    _reset_reference_scroll()


func _render_career_summary() -> void:
    var previous := body.get_node_or_null("ReferenceLegacySelection")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var state: Dictionary = GameState.state
    var view := REFERENCE_LEGACY.new()
    view.name = "ReferenceLegacySelection"
    view.boxer = state.get("boxer", {})
    view.career = state.get("career", {})
    view.meta = state.get("meta_state", {})
    view.profile = GameState.retirement_legacy_profile()
    view.ending = GameState.ending_text()
    view.milestone = state.get("career_state", {}).get("milestone", {})
    view.notice = legacy_notice
    view.pending = GameState.pending_retirement_legacy()
    view.selected = state.get("career_state", {}).get("retirement_legacy_selected", {})
    if view.pending.is_empty() and view.selected.is_empty():
        view.candidates = GameState.retirement_legacy_candidates()
    view.definition_for = GameState.legacy_definition
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.legacy_chosen.connect(_choose_retirement_legacy)
    view.slot_replaced.connect(_replace_retirement_legacy)
    view.legacy_abandoned.connect(_abandon_retirement_legacy)
    view.next_requested.connect(_start_next_generation)
    body.add_child(view)
    _reset_reference_scroll()


func _render_style_select() -> void:
    _render_reference_creation(true)

func _render_talent_reveal() -> void:
    if _tutorial_active() and not bool(GameState.state.get("first_cycle_tutorial", {}).get("talent_roll_seen", false)):
        _render_random_talent_roll()
    else:
        _render_reference_creation(false)


func _render_random_talent_roll() -> void:
    var view := FIRST_CYCLE_TALENT_ROLL.new()
    view.talents = GameState.talent_options()
    view.chosen_id = str(GameState.state.get("boxer", {}).get("trait_id", ""))
    view.bold_font = _v18_font(620)
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.reveal_requested.connect(_complete_random_talent_roll)
    view.tutorial_skipped.connect(_skip_first_bout_guide)
    body.add_child(view)
    _reset_reference_scroll()


func _complete_random_talent_roll() -> void:
    if str(GameState.state.get("phase", "")) != "talent_reveal":
        return
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
    tutorial["talent_roll_seen"] = true
    GameState.state["first_cycle_tutorial"] = tutorial
    SaveService.save_game(GameState.state)
    _render_phase()

func _render_reference_creation(choosing_style: bool, choosing_talent: bool = false) -> void:
    var previous := body.get_node_or_null("ReferenceBoxerCreation")
    if previous != null:
        body.remove_child(previous)
        if not previous.is_queued_for_deletion():
            previous.queue_free()
    var view := REFERENCE_CREATION.new()
    view.name = "ReferenceBoxerCreation"
    view.career = GameState
    view.choosing_style = choosing_style
    view.choosing_talent = choosing_talent
    view.talent_requires_choice = false
    view.random_talent_mode = true
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    for stat: String in REFERENCE_CREATION.STATS:
        view.stat_help[stat] = GameState.stat_help(stat)
    if choosing_style:
        view.styles = GameState.boxing_styles()
    elif choosing_talent:
        view.boxer = GameState.state.get("boxer", {})
        view.talents = GameState.talent_options()
    else:
        view.boxer = GameState.state.get("boxer", {})
        view.talent = GameState.talent_definition()
    view.style_chosen.connect(_choose_boxing_style, CONNECT_DEFERRED)
    view.talent_confirmed.connect(_confirm_talent, CONNECT_DEFERRED)
    view.style_reselect_requested.connect(_return_to_style_selection, CONNECT_DEFERRED)
    view.talent_picker_requested.connect(_open_talent_picker, CONNECT_DEFERRED)
    view.talent_chosen.connect(_select_talent, CONNECT_DEFERRED)
    view.talent_picker_cancelled.connect(_close_talent_picker, CONNECT_DEFERRED)
    body.add_child(view)
    _reset_reference_scroll()

func _return_to_style_selection() -> void:
    if str(GameState.state.get("phase", "")) != "talent_reveal":
        return
    GameState.begin_boxer_creation()
    if _tutorial_active():
        var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
        tutorial["talent_roll_seen"] = false
        GameState.state["first_cycle_tutorial"] = tutorial
        SaveService.save_game(GameState.state)
    _render_phase()

func _open_talent_picker() -> void:
    # Natural talent is random, not a player choice.
    return

func _select_talent(_talent_id: String) -> void:
    return

func _close_talent_picker() -> void:
    return

func _confirm_talent() -> void:
    if _tutorial_active() and not bool(GameState.state.get("first_cycle_tutorial", {}).get("talent_roll_seen", false)):
        _render_random_talent_roll()
        return
    super._confirm_talent()


func _render_launch_title() -> void:
    _clear_body()
    _set_title_shell_visible(false)
    var previous := get_node_or_null("ReferenceTitle")
    if previous != null:
        remove_child(previous)
        previous.queue_free()
    var view := REFERENCE_TITLE.new()
    view.name = "ReferenceTitle"
    view.settings_icon = _v18_line_icon("settings")
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(580)
    view.can_continue = _has_career_to_continue()
    if view.can_continue:
        var state: Dictionary = GameState.state
        var career: Dictionary = state.get("career", {})
        view.save_caption = "%s · %d세대 · %d전" % [
            str(state.get("boxer", {}).get("name", "무명 복서")),
            int(state.get("meta_state", {}).get("generation", 1)),
            int(career.get("fights", 0)),
        ]
    view.new_career_requested.connect(_start_new_career_from_title)
    view.continue_requested.connect(_continue_from_reference_title)
    view.settings_requested.connect(_open_title_settings)
    add_child(view)
    view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _render_status()
    _configure_mobile_scroll()
    var scroll := find_child("V17ContentScroll", true, false) as ScrollContainer
    if scroll != null:
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
    _reset_reference_scroll()
    _v17_sync_nav()
    _sync_music_for_phase()
    call_deferred("_wire_ui_sounds")

func _set_title_shell_visible(visible: bool) -> void:
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

func _should_show_launch_title() -> bool:
    # Every app launch starts at the title; do not consume or overwrite saved career progress.
    return true

func _has_career_to_continue() -> bool:
    # Preserve the original fresh-install placeholder check for the Continue button.
    return not GameState.state.is_empty() and not super._should_show_launch_title()

func _return_to_reference_title() -> void:
    v17_overlay = ""
    v19_previous_overlay = ""
    launch_gate_active = true
    _render_phase()

func _continue_from_reference_title() -> void:
    if not launch_gate_active or not _has_career_to_continue():
        return
    launch_gate_active = false
    v17_overlay = "home"
    _render_phase()
    _reset_reference_scroll()

func _start_new_career_from_title() -> void:
    if not launch_gate_active:
        return
    current_opponent = {}
    combat = null
    super._start_new_career_from_title()
    var guided := _first_bout_guide_enabled() and not bool(_onboarding_install.get_value("install", "tutorial_started", false))
    _mark_onboarding_started()
    GameState.state["first_cycle_tutorial"] = {"active": guided, "complete": false, "talent_roll_seen": false, "actions_seen": []}
    if guided:
        GameState.state["phase"] = "tutorial_welcome"
        v17_overlay = ""
    else:
        v17_overlay = "home"
    SaveService.save_game(GameState.state)
    _render_phase()
    _reset_reference_scroll()


func _mark_onboarding_started() -> void:
    _onboarding_install.set_value("install", "tutorial_started", true)
    if _onboarding_install.save(INSTALL_ONBOARDING_SETTINGS) != OK:
        push_warning("Unable to persist first-install tutorial marker.")


func _dev_reset_enabled() -> bool:
    return OS.has_feature("editor") or OS.has_feature("tc_dev_preview") or bool(ProjectSettings.get_setting(DEV_RESET_SETTING, false))


func _install_dev_reset_confirmation() -> void:
    if not _dev_reset_enabled() or _dev_reset_confirmation != null:
        return
    _dev_reset_confirmation = ConfirmationDialog.new()
    _dev_reset_confirmation.name = "DevFactoryResetConfirmation"
    _dev_reset_confirmation.title = "개발용 전체 초기화"
    _dev_reset_confirmation.dialog_text = "이 브라우저의 선수·전적·유산·튜토리얼 저장 정보를 삭제합니다. 취소할 수 없습니다."
    _dev_reset_confirmation.ok_button_text = "전체 초기화"
    _dev_reset_confirmation.cancel_button_text = "취소"
    _dev_reset_confirmation.dialog_autowrap = true
    _dev_reset_confirmation.confirmed.connect(_confirm_dev_factory_reset)
    add_child(_dev_reset_confirmation)


func _request_dev_factory_reset() -> void:
    if not _dev_reset_enabled():
        return
    _install_dev_reset_confirmation()
    _dev_reset_confirmation.popup_centered(Vector2i(350, 0))


func _confirm_dev_factory_reset() -> void:
    if not _dev_reset_enabled():
        return
    # Remove current and legacy backups before generating the fresh save,
    # preventing an obsolete backup from being loaded later.
    for path in [
        SaveService.SAVE_PATH,
        SaveService.BACKUP_PATH,
        SaveService.PREVIOUS_SAVE_PATH,
        SaveService.PREVIOUS_BACKUP_PATH,
        "user://career_v1.json",
        "user://career_v1.backup.json",
        INSTALL_ONBOARDING_SETTINGS,
        FIRST_BOUT_GUIDE_SETTINGS,
    ]:
        if FileAccess.file_exists(path):
            var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
            if error != OK:
                push_warning("Failed removing developer reset file: " + path)
    _guide_settings.clear()
    _onboarding_install.clear()
    _guide_settings.set_value("tutorial", "enabled", true)
    _guide_settings.save(FIRST_BOUT_GUIDE_SETTINGS)
    v17_overlay = ""
    v19_previous_overlay = ""
    current_opponent = {}
    combat = null
    # Factory reset returns to the title without entering a career.
    # A tutorial starts only when the player explicitly begins a new career
    # with no previous onboarding/usage record.
    GameState.new_career("무명 복서")
    GameState.state.erase("first_launch_acknowledged")
    GameState.state.erase("first_cycle_tutorial")
    SaveService.save_game(GameState.state)
    launch_gate_active = true
    _render_phase()


# Keep real career state distinct from navigation-only panels.
func _render_phase() -> void:
    if not launch_gate_active:
        _leave_title_overlay()
    if launch_gate_active:
        _render_launch_title()
        return
    if _tutorial_special_screen():
        _render_tutorial_story()
        return
    if v17_overlay.is_empty() and GameState.state.phase in ["season_review", "champion_choice", "sponsor_offer", "gym_fund_intro"]:
        _clear_body()
        _render_status()
        if GameState.state.phase == "gym_fund_intro":
            _render_gym_fund_intro()
        elif GameState.state.phase == "sponsor_offer":
            _render_sponsorship_decision()
        else:
            _render_career_decision()
        _configure_mobile_scroll()
        _v17_sync_nav()
        _reset_reference_scroll()
        return
    if v17_overlay in ["match_blocked", "training_blocked"]:
        _clear_body()
        _render_status()
        _v19_render_blocked_tab(v17_overlay)
        _configure_mobile_scroll()
        _v17_sync_nav()
        return
    if v17_overlay in ["home", "schedule"]:
        _clear_body()
        _render_status()
        if v17_overlay == "home":
            _v19_render_home()
        else:
            _v19_render_schedule()
        _configure_mobile_scroll()
        _v17_sync_nav()
        _sync_music_for_phase()
        call_deferred("_wire_ui_sounds")
        return
    super._render_phase()
    call_deferred("_tutorial_attach")

func _render_gym_fund_intro() -> void:
    _v17_section_heading("3경기 달성 · 체육관 공동 모금", "선수 육성에 투자할 새로운 선택지가 열렸습니다.")
    var highlight := _v17_panel(body, true)
    highlight.add_theme_constant_override("separation", 10)
    var eyebrow := _v17_eyebrow(highlight, "NEW CAREER MILESTONE")
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var amount := _v17_title(highlight, "+25,000원", 33)
    amount.add_theme_color_override("font_color", V17_GOLD)
    amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var summary := _v17_copy(highlight, "3경기를 마친 선수를 위해 체육관 공동 모금이 도착했습니다.", false)
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var detail := _v17_panel(body, false)
    _v17_title(detail, "새롭게 열린 기능", 18)
    _v17_copy(detail, "장비 구매와 체육관 시설 투자를 통해 앞으로의 훈련 효율을 개선할 수 있습니다.", false)
    _v17_copy(detail, "지금 살펴볼 수도 있고, 이후 상점에서 다시 확인할 수도 있습니다.", true)
    var shop_button := _v17_gold_button("체육관 투자 살펴보기")
    shop_button.name = "GymFundOpenShop"
    shop_button.custom_minimum_size.y = 54
    shop_button.pressed.connect(_open_gym_fund_shop)
    body.add_child(shop_button)
    var skip_button := _v17_dark_button("나중에 확인하기")
    skip_button.name = "GymFundSkipShop"
    skip_button.custom_minimum_size.y = 48
    skip_button.pressed.connect(_skip_gym_fund_shop)
    body.add_child(skip_button)

func _open_gym_fund_shop() -> void:
    if GameState.open_gym_fund_shop():
        _equipment_section = "personal"
        _equipment_receipt = {}
        _render_phase()
        _reset_reference_scroll()

func _skip_gym_fund_shop() -> void:
    if GameState.skip_gym_fund_shop():
        _render_phase()
        _reset_reference_scroll()

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

func _open_equipment_shop() -> void:
    if str(GameState.state.get("phase", "")) == "camp":
        _equipment_section = "personal"
        _equipment_receipt = {}
    super._open_equipment_shop()
    _reset_reference_scroll()

func _return_from_equipment_shop() -> void:
    if not GameState.leave_equipment_shop():
        return
    _equipment_receipt = {}
    _render_phase()
    _reset_reference_scroll()

func _render_equipment_shop() -> void:
    _render_reference_shop(false)

func _v17_render_shop_hint() -> void:
    _render_reference_shop(true)

func _render_reference_shop(unavailable: bool) -> void:
    var previous := body.get_node_or_null("ReferenceEquipmentShop")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var view := REFERENCE_EQUIPMENT.new()
    view.name = "ReferenceEquipmentShop"
    view.unavailable = unavailable
    view.money_text = _v17_money
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    if unavailable:
        view.back_requested.connect(_v19_return_to_phase, CONNECT_DEFERRED)
    else:
        view.section = _equipment_section
        view.receipt = _equipment_receipt if _equipment_receipt.get("section") == _equipment_section else {}
        view.purchase_complete = not str(GameState.state.get("last_camp_action", "")).is_empty()
        view.money = int(GameState.state["career"]["money"])
        view.spent = GameState.equipment_total_spent()
        view.slots = _equipment_slots_for_view(_equipment_section)
        view.section_requested.connect(_select_reference_equipment_section, CONNECT_DEFERRED)
        view.purchase_requested.connect(_purchase_reference_equipment, CONNECT_DEFERRED)
        view.back_requested.connect(_return_from_equipment_shop, CONNECT_DEFERRED)
    if bool(GameState.state.get("career_state", {}).get("gym_fund_shop_active", false)):
        _v17_section_heading("장비 구매 가이드", "개인 장비와 체육관 장비를 비교해 보세요. 장비를 구매하면 캠프 활동 1회를 사용하며, 구매 없이 돌아갈 수도 있습니다.")
    body.add_child(view)

func _equipment_slots_for_view(section: String) -> Array[Dictionary]:
    var slots: Array[Dictionary] = []
    for slot: String in GameState.equipment_slots(section):
        var current: Dictionary = GameState.current_equipment(section, slot)
        var upgrade: Dictionary = GameState.next_equipment_upgrade(section, slot)
        var details := {
            "slot": slot,
            "label": _equipment_slot_name(section, slot, current, upgrade),
            "current": current,
            "upgrade": upgrade,
        }
        if not upgrade.is_empty():
            details["eligibility"] = GameState.can_purchase_equipment(section, str(upgrade["id"]))
            if section == "personal":
                details["stat_changes"] = GameState.equipment_stat_changes(current, upgrade)
            else:
                var names: Array[String] = []
                for action: Dictionary in camp_actions:
                    if str(action["id"]) in upgrade.get("action_ids", []):
                        names.append(REFERENCE_TRAINING.action_title(action))
                details["training_names"] = " · ".join(names)
        slots.append(details)
    return slots

func _select_reference_equipment_section(section: String) -> void:
    if str(GameState.state.get("phase", "")) != "equipment_shop" or section == _equipment_section:
        return
    _equipment_section = section
    _render_phase()
    _reset_reference_scroll()

func _purchase_reference_equipment(section: String, item_id: String) -> void:
    if str(GameState.state.get("phase", "")) != "equipment_shop" or section != _equipment_section:
        return
    var before_money := int(GameState.state["career"]["money"])
    var bought: Dictionary = GameState.purchase_equipment(section, item_id)
    if bool(bought.get("ok", false)):
        var item: Dictionary = bought["item"]
        _equipment_receipt = {
            "section": section,
            "slot": str(item.get("slot", "")),
            "name": str(item.get("name", "")),
            "before_money": before_money,
            "stat_changes": bought.get("stat_changes", {}),
            "old_efficiency": int(bought.get("previous", {}).get("training_percent", 0)),
            "new_efficiency": int(item.get("training_percent", 0)),
        }
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
            if str(GameState.state.get("last_camp_action", "")).is_empty():
                _v17_copy(panel, "장비를 살펴보고 구매 여부를 결정하세요. 구매하지 않고 돌아가도 캠프는 유지됩니다.", true)
            else:
                _v17_copy(panel, "장비 구매가 완료되었습니다. 구매 결과를 확인한 뒤 경기 제안으로 이동하세요.", true)
        elif phase == "camp":
            _v17_title(panel, "경기 준비 중", 22)
            _v17_copy(panel, "관리 메뉴에서 활동 하나를 마치면 경기 제안이 열립니다.", true)
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
        var return_label := "경기 제안으로 이동" if not str(GameState.state.get("last_camp_action", "")).is_empty() else "훈련 캠프로 돌아가기"
        _v19_menu_button(panel, return_label, Callable(self, "_return_from_equipment_shop"))
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
    _v19_menu_button(panel, "가이드 다시 보기", _v19_open_first_bout_guide)
    _v19_menu_button(panel, "타이틀 화면", Callable(self, "_return_to_reference_title"))
    _v19_menu_button(panel, "닫기", Callable(self, "_v19_close_secondary"))
    _v17_sync_nav()

func _v19_open_settings() -> void:
    v19_previous_overlay = v17_overlay
    v17_overlay = ""
    _clear_body()
    _v17_section_heading("설정", "게임 실행 옵션")
    var panel := _v17_panel(body, false)
    var mute := CheckButton.new()
    mute.name = "SettingsMuteAudio"
    mute.text = "모든 게임 소리 끄기"
    mute.button_pressed = AudioServer.is_bus_mute(0)
    mute.custom_minimum_size.y = 54
    mute.add_theme_font_override("font", _v18_font(620))
    mute.add_theme_color_override("font_color", V17_TEXT)
    mute.add_theme_color_override("font_hover_color", V17_GOLD)
    mute.toggled.connect(func(value: bool): AudioServer.set_bus_mute(0, value))
    panel.add_child(mute)
    if _dev_reset_enabled():
        var dev_panel := _v17_panel(body, false)
        _v17_copy(dev_panel, "개발자 도구 · 브라우저의 전체 게임 데이터를 초기화합니다.", true)
        var reset_button := REFERENCE_UI.action_button("개발용 전체 초기화", _v18_font(620), false)
        reset_button.name = "DevFactoryResetButton"
        reset_button.custom_minimum_size.y = 54
        reset_button.pressed.connect(_request_dev_factory_reset)
        dev_panel.add_child(reset_button)
    _v19_menu_button(panel, "가이드 다시 보기", _v19_open_first_bout_guide)
    _v19_menu_button(panel, "게임으로 돌아가기", Callable(self, "_v19_close_secondary"))
    _v17_sync_nav()

func _v19_open_first_bout_guide() -> void:
    _clear_body()
    _v17_section_heading("첫 경기 가이드", "훈련 → 경기 준비 → 전투 → 정산")
    for step: Array in [
        ["1/4  훈련", "캠프마다 훈련이나 회복을 한 번 고릅니다. 결과에서 능력치, 피로, 체중 변화를 확인하세요."],
        ["2/4  경기 준비", "난이도와 보상을 비교해 상대를 고릅니다. 상대 습관에 맞춰 전술을 준비하고, 계체 기준에 맞게 컨디션을 조정하세요. 상대 분석에서 추천 게임플랜을 확인할 수 있습니다."],
        ["3/4  전투", "교환 전에 상대 움직임과 예측을 읽고 행동 하나를 고릅니다. 가드는 스태미나를 회복할 때 쓸 수 있습니다."],
        ["4/4  정산", "판정과 입금, 건강과 피로를 확인한 다음 다음 캠프를 준비하세요. 랭킹을 올려 타이틀에 도전하고, 은퇴하면 유산을 다음 선수에게 물려줄 수 있습니다."],
    ]:
        var panel := _v17_panel(body, true)
        _v17_eyebrow(panel, step[0])
        _v17_copy(panel, step[1], false)
    var controls := _v17_panel(body, false)
    var enabled := CheckButton.new()
    enabled.name = "FirstBoutGuideToggle"
    enabled.text = "첫 경기 중 안내 표시"
    enabled.add_theme_color_override("font_color", V17_TEXT)
    enabled.add_theme_color_override("font_hover_color", V17_GOLD)
    enabled.add_theme_color_override("font_pressed_color", V17_TEXT)
    enabled.button_pressed = _first_bout_guide_enabled()
    enabled.toggled.connect(_set_first_bout_guide)
    enabled.custom_minimum_size.y = 54
    controls.add_child(enabled)
    var back := REFERENCE_UI.action_button("게임으로 돌아가기", _v18_font(620), true)
    back.name = "FirstBoutGuideBack"
    back.pressed.connect(_v19_close_secondary)
    controls.add_child(back)
    _configure_mobile_scroll()
    _reset_reference_scroll()

func _first_bout_guide_enabled() -> bool:
    return bool(_guide_settings.get_value("tutorial", "enabled", true))

func _show_first_bout_guide(fight_count: int = 0) -> bool:
    var state: Dictionary = GameState.state
    return (
        _tutorial_active()
        and int(state.get("career", {}).get("fights", 0)) == fight_count
    )

func _set_first_bout_guide(enabled: bool) -> void:
    _guide_settings.set_value("tutorial", "enabled", enabled)
    if _guide_settings.save(FIRST_BOUT_GUIDE_SETTINGS) != OK:
        push_warning("Could not save the first-bout guide preference.")
    if not GameState.state.is_empty() and GameState.state.has("first_cycle_tutorial"):
        var tutorial: Dictionary = GameState.state["first_cycle_tutorial"].duplicate(true)
        if not bool(tutorial.get("complete", false)):
            # Once dismissed it cannot be reactivated on a later career.
            tutorial["active"] = bool(tutorial.get("active", false)) and enabled
            GameState.state["first_cycle_tutorial"] = tutorial
            SaveService.save_game(GameState.state)

func _skip_first_bout_guide() -> void:
    if str(GameState.state.get("phase", "")) in ["tutorial_welcome", "tutorial_overview"]:
        GameState.state["phase"] = "style_select"
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
    tutorial.erase("training_result_pending")
    tutorial.erase("complete_pending")
    tutorial["active"] = false
    GameState.state["first_cycle_tutorial"] = tutorial
    SaveService.save_game(GameState.state)
    _set_first_bout_guide(false)
    _render_phase()

func _v19_menu_button(parent: Node, label_text: String, action: Callable) -> void:
    var btn := Button.new()
    btn.text = label_text
    btn.custom_minimum_size = Vector2(0, 54)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.add_theme_font_override("font", _v18_font(650))
    btn.add_theme_font_size_override("font_size", 15)
    btn.add_theme_color_override("font_color", V17_TEXT)
    btn.add_theme_color_override("font_hover_color", V17_GOLD)
    btn.add_theme_color_override("font_pressed_color", V17_GOLD)
    btn.add_theme_stylebox_override("normal", REFERENCE_UI.beveled_panel_style(Color("#111e2b"), V17_BORDER, 8))
    btn.add_theme_stylebox_override("hover", REFERENCE_UI.beveled_panel_style(Color("#1b2b3b"), V17_GOLD, 8))
    btn.add_theme_stylebox_override("pressed", REFERENCE_UI.beveled_panel_style(Color("#241d12"), V17_GOLD, 8))
    btn.pressed.connect(action)
    parent.add_child(btn)

func _v19_close_secondary() -> void:
    v17_overlay = v19_previous_overlay
    _render_phase()

func _v17_render_career_home() -> void:
    var previous := body.get_node_or_null("ReferenceCareerRecord")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var state: Dictionary = GameState.state
    if state.career_state.has("milestone"):
        _review_panel("12전 커리어 평가", state.career_state.milestone)
    var view := REFERENCE_CAREER.new()
    view.name = "ReferenceCareerRecord"
    view.boxer = state.get("boxer", {})
    view.career = state.get("career", {})
    view.career_state = state.get("career_state", {})
    view.recent = state.get("last_fight_summary", {})
    var latest := str(view.recent.get("result", state.get("last_result", "")))
    view.recent_result = _result_label(latest) if not latest.is_empty() else ""
    view.titles = GameState.ladder_titles()
    view.stage_label = "세계 챔피언" if bool(view.career.get("champion", false)) else str(GameState.career_ladder_stage().get("label", ""))
    view.next_stage = GameState.career_ladder_next_stage()
    if view.next_stage.get("id") == "world":
        view.required_points = GameState.WORLD_TITLE_MIN_POINTS
        view.title_ready = GameState.world_title_ready()
    elif not view.next_stage.is_empty():
        view.title_ready = int(view.career.get("fights", 0)) >= int(view.next_stage["min_fights"]) \
            and int(view.career.get("wins", 0)) >= int(view.next_stage["min_wins"])
    var meta: Dictionary = state.get("meta_state", {})
    view.generation = int(meta.get("generation", 1))
    view.legacy_capacity = int(meta.get("legacy_capacity", 3))
    var slots: Array = meta.get("legacy_slots", [])
    view.legacy_count = slots.size()
    for slot in slots:
        if slot is Dictionary:
            var label := _career_legacy_name(str(slot.get("definition_id", "")))
            if not label.is_empty():
                view.active_legacies.append(label)
    var history: Array = meta.get("lineage_history", [])
    for index in range(history.size() - 1, -1, -1):
        if history[index] is Dictionary:
            var record: Dictionary = history[index].duplicate()
            record["legacy_name"] = _career_legacy_name(str(record.get("legacy_definition_id", "")))
            if not record.has("legacy_status") and bool(record.get("legacy_active", false)):
                record["legacy_status"] = "active"
            view.lineage.append(record)
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.money_text = _v17_money
    body.add_child(view)
    _reset_reference_scroll()

func _career_legacy_name(id: String) -> String:
    var definition: Dictionary = GameState.legacy_definition(id)
    return str(definition.get("name", ""))


func _v19_open_home() -> void:
    v17_overlay = "home"
    _render_phase()

func _v19_open_schedule() -> void:
    v17_overlay = "schedule"
    _render_phase()

func _v19_continue_from_home() -> void:
    v17_overlay = ""
    _render_phase()

func _v19_render_home() -> void:
    var view := REFERENCE_HOME.new()
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.training_requested.connect(_v17_open_training, CONNECT_DEFERRED)
    view.match_requested.connect(_v17_open_match, CONNECT_DEFERRED)
    view.profile_requested.connect(Callable(self, "_v17_open_overlay").bind("profile"), CONNECT_DEFERRED)
    view.ranking_requested.connect(Callable(self, "_v17_open_overlay").bind("career"), CONNECT_DEFERRED)
    view.management_requested.connect(_v17_open_shop, CONNECT_DEFERRED)
    view.continue_requested.connect(_v19_continue_from_home, CONNECT_DEFERRED)
    body.add_child(view)
    _reset_reference_scroll()

func _v19_render_schedule() -> void:
    var career: Dictionary = GameState.state.get("career", {})
    var phase := str(GameState.state.get("phase", "camp"))
    var phase_labels := {
        "camp":"훈련 캠프",
        "equipment_shop":"장비 및 체육관 관리",
        "fight_offer":"상대 선택",
        "tactical_prep":"전술 준비",
        "condition_prep":"컨디션 준비",
        "game_plan":"경기 전략 설정",
        "fight":"경기 진행",
        "result":"경기 결과 확인",
        "season_review":"시즌 검토",
        "champion_choice":"챔피언 도전",
        "sponsor_offer":"스폰서 계약",
        "gym_fund_intro":"체육관 투자 안내",
        "career_summary":"커리어 마무리"
    }
    var fights := int(career.get("fights", 0))
    var season := 1 + fights / 4
    var season_fights := fights % 4
    var step_index := 0
    if phase in ["equipment_shop", "fight_offer"]:
        step_index = 1
    elif phase in ["tactical_prep", "condition_prep", "game_plan"]:
        step_index = 2
    elif phase == "fight":
        step_index = 3
    elif phase in ["result", "season_review", "champion_choice", "sponsor_offer", "gym_fund_intro", "career_summary"]:
        step_index = 4

    _v17_section_heading("일정", "시즌 진행 상황과 다음 경기까지의 준비 단계를 확인하세요.")

    var season_panel := _v17_panel(body, true)
    _v17_eyebrow(season_panel, "SEASON SCHEDULE")
    _v17_title(season_panel, "시즌 %d · %d번째 경기" % [season, fights + 1], 24)
    _v17_copy(season_panel, "현재 단계 · %s" % str(phase_labels.get(phase, "커리어 진행")), false)
    var world: Dictionary = GameState.state.get("world_state", {})
    var date: Dictionary = world.get("world_date", {})
    if not date.is_empty():
        _v17_copy(season_panel, "리그 일정 · %04d년 %02d월" % [int(date.get("year", 0)), int(date.get("month", 1))], true)

    var progress_row := HBoxContainer.new()
    progress_row.add_theme_constant_override("separation", 6)
    season_panel.add_child(progress_row)
    _v19_schedule_metric(progress_row, "이번 시즌", "%d / 4경기" % season_fights)
    _v19_schedule_metric(progress_row, "누적 전적", "%d승 %d패 %d무" % [
        int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0))
    ])
    _v19_schedule_metric(progress_row, "현재 랭킹", "#%d" % int(career.get("rank", 0)))

    var progress := ProgressBar.new()
    progress.name = "ScheduleSeasonProgress"
    progress.min_value = 0
    progress.max_value = 4
    progress.value = season_fights
    progress.show_percentage = false
    progress.custom_minimum_size.y = 9
    progress.add_theme_stylebox_override("background", _v17_box_style(Color("#263542"), Color("#263542"), 3, 0))
    progress.add_theme_stylebox_override("fill", _v17_box_style(V17_GOLD, V17_GOLD, 3, 0))
    progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
    season_panel.add_child(progress)

    var timeline := _v17_panel(body, false)
    _v17_eyebrow(timeline, "ROAD TO THE NEXT BOUT")
    _v17_title(timeline, "다음 경기까지의 진행 순서", 18)
    var steps := GridContainer.new()
    steps.name = "ScheduleTimeline"
    steps.columns = 4
    steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    steps.add_theme_constant_override("h_separation", 5)
    timeline.add_child(steps)
    var step_labels := ["훈련", "상대", "준비", "경기"]
    for index in range(step_labels.size()):
        _v19_schedule_step(steps, index, step_labels[index], index == step_index, index < step_index)

    var next_panel := _v17_panel(body, true)
    _v17_eyebrow(next_panel, "NEXT MATCH")
    if not current_opponent.is_empty():
        _v17_title(next_panel, _v17_opponent_name(current_opponent), 21)
        _v17_copy(next_panel, "상대 랭킹 #%d · %s" % [
            int(current_opponent.get("rank", 0)),
            _style_label(str(current_opponent.get("style", "")))
        ], false)
        _v17_copy(next_panel, "현재 진행 단계에서 상대 분석과 경기 준비를 이어갈 수 있습니다.", true)
    elif phase == "camp":
        _v17_title(next_panel, "다음 상대 선택 대기", 20)
        _v17_copy(next_panel, "이번 캠프의 훈련을 마치면 다음 경기 제안을 확인할 수 있습니다.", true)
    else:
        _v17_title(next_panel, "다음 경기 준비", 20)
        _v17_copy(next_panel, "현재 단계 · %s" % str(phase_labels.get(phase, "커리어 진행")), true)

    var action := _v17_gold_button("현재 단계 이어가기  ›")
    action.name = "ScheduleContinue"
    action.custom_minimum_size.y = 56
    action.pressed.connect(_v19_continue_from_home)
    body.add_child(action)
    _reset_reference_scroll()

func _v19_schedule_metric(parent: HBoxContainer, title: String, value: String) -> void:
    var metric := VBoxContainer.new()
    metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    metric.add_theme_constant_override("separation", 2)
    parent.add_child(metric)
    _v17_eyebrow(metric, title)
    var label := _v17_title(metric, value, 15)
    label.add_theme_color_override("font_color", V17_TEXT)

func _v19_schedule_step(parent: GridContainer, index: int, title: String, active: bool, completed: bool) -> void:
    var card := _v17_panel(parent, active)
    card.name = "ScheduleStep_%d" % index
    card.add_theme_constant_override("separation", 3)
    var number := _v17_title(card, "0%d" % (index + 1), 19)
    number.add_theme_color_override("font_color", V17_GOLD if active or completed else V17_MUTED)
    var name := _v17_copy(card, title, false)
    name.add_theme_font_size_override("font_size", 11)
    var status := "완료" if completed else ("진행 중" if active else "대기")
    _v17_copy(card, status, true)

# Reference-accurate boxer profile; other tabs keep their validated flow.
func _v17_render_profile_home() -> void:
    var profile_view := preload("res://scripts/ui/reference_profile_view.gd").new()
    profile_view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    profile_view.bold_font = _v18_font(650)
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
    var previous := body.get_node_or_null("ReferenceTraining")
    if previous != null and previous.is_queued_for_deletion():
        body.remove_child(previous)
    var training := REFERENCE_TRAINING.new()
    training.actions = camp_actions
    training.show_first_bout_guide = false
    training.guide_skipped.connect(_skip_first_bout_guide)
    training.bold_font = _v18_font(620)
    training.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    training.action_chosen.connect(_choose_camp_action)
    training.shop_requested.connect(_open_training_upgrade_shop)
    training.media_requested.connect(func():
        if GameState.management_visit():
            _render_phase()
    )
    body.add_child(training)
    _reset_reference_scroll()

func _open_training_upgrade_shop() -> void:
    _open_equipment_shop()
    if str(GameState.state.get("phase", "")) == "equipment_shop":
        _equipment_section = "gym"
        _render_phase()
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
    if _tutorial_active():
        var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
        tutorial["training_result_pending"] = true
        GameState.state["first_cycle_tutorial"] = tutorial
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
    view.heading_font = REFERENCE_UI.heading_font(_v18_font(780))
    view.bold_font = _v18_font(620)
    view.show_first_bout_guide = _tutorial_active()
    var available_offers: Array = GameState.get_fight_offers(opponents)
    if _tutorial_active() and not available_offers.is_empty():
        var recommend: Dictionary = available_offers[0]
        for candidate: Dictionary in available_offers:
            if str(candidate.get("difficulty", "")) == "safe":
                recommend = candidate
                break
        view.recommended_opponent_id = str(recommend.get("id", ""))
    for opponent: Dictionary in available_offers:
        view.offers.append({
            "opponent": opponent,
            "portrait": _v17_opponent_texture(opponent),
            "style": _style_label(str(opponent.get("style", ""))),
            "country": _v17_country(opponent),
            "purse": _v17_money(GameState.quoted_purse(opponent)),
        })
    view.opponent_chosen.connect(_accept_reference_offer)
    view.tutorial_skipped.connect(_skip_first_bout_guide)
    body.add_child(view)
    var action_id := str(GameState.state.last_camp_action)
    if action_id == "media_visit":
        _v17_copy(view, "팬 미팅 완료 · 인기 +2", true)
    elif GameState.equipment_total_spent() > 0 and not GameState.equipment_definition(action_id).is_empty():
        _v17_copy(view, "장비 구매 완료 · " + str(GameState.equipment_definition(action_id).name), true)
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

# One continuous first-career tutorial. Progress follows the real saved game phase,
# while combat action milestones are stored as actual player inputs.
func _tutorial_active() -> bool:
    if GameState.state.is_empty() or not _first_bout_guide_enabled():
        return false
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {})
    var career: Dictionary = GameState.state.get("career", {})
    var generation := int(GameState.state.get("meta_state", {}).get("generation", 1))
    return bool(tutorial.get("active", false)) and not bool(tutorial.get("complete", false)) and generation == 1 and int(career.get("fights", 0)) <= 1


func _tutorial_next_action() -> String:
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {})
    var seen: Array = tutorial.get("actions_seen", [])
    for action in ["jab", "guard", "counter"]:
        if not seen.has(action):
            return action
    return ""


func _choose_fight_action(action: String) -> void:
    if fight_input_locked:
        return
    if _tutorial_active() and str(GameState.state.get("phase", "")) == "fight":
        var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
        var seen: Array = tutorial.get("actions_seen", []).duplicate()
        if action in ["jab", "guard", "body", "power", "counter"]:
            if not seen.has(action):
                seen.append(action)
            tutorial["actions_seen"] = seen
            # Keep the next required control highlighted until it is actually used.
            GameState.state["first_cycle_tutorial"] = tutorial
            SaveService.save_game(GameState.state)
    super._choose_fight_action(action)
    call_deferred("_tutorial_attach")


func _tutorial_special_screen() -> bool:
    if not v17_overlay.is_empty():
        return false
    var phase := str(GameState.state.get("phase", ""))
    if phase in ["tutorial_welcome", "tutorial_overview"]:
        return true
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {})
    return bool(tutorial.get("training_result_pending", false)) or bool(tutorial.get("complete_pending", false))


func _render_tutorial_story() -> void:
    var previous_spotlight := get_node_or_null("FirstCycleSpotlight")
    if previous_spotlight != null:
        remove_child(previous_spotlight)
        previous_spotlight.queue_free()
    _clear_body()
    _render_status()
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {})
    var phase := str(GameState.state.get("phase", ""))
    var view := FIRST_CYCLE_STORY.new()
    view.name = "FirstCycleStory"
    if phase == "tutorial_welcome":
        view.mode = "welcome"
    elif phase == "tutorial_overview":
        view.mode = "overview"
    elif bool(tutorial.get("training_result_pending", false)):
        view.mode = "training_result"
        view.training_result = GameState.state.get("last_camp_result", {})
    else:
        view.mode = "finished"
    view.font = _v18_font(620)
    view.actions_seen = tutorial.get("actions_seen", []).duplicate()
    view.next_requested.connect(_tutorial_story_next)
    view.skip_requested.connect(_skip_first_bout_guide)
    body.add_child(view)
    _configure_mobile_scroll()
    _reset_reference_scroll()
    _v17_sync_nav()


func _tutorial_story_next() -> void:
    var phase := str(GameState.state.get("phase", ""))
    var tutorial: Dictionary = GameState.state.get("first_cycle_tutorial", {}).duplicate(true)
    if phase == "tutorial_welcome":
        GameState.state["phase"] = "tutorial_overview"
    elif phase == "tutorial_overview":
        GameState.state["phase"] = "style_select"
    elif bool(tutorial.get("training_result_pending", false)):
        tutorial.erase("training_result_pending")
    elif bool(tutorial.get("complete_pending", false)):
        tutorial.erase("complete_pending")
    GameState.state["first_cycle_tutorial"] = tutorial
    SaveService.save_game(GameState.state)
    _render_phase()


func _tutorial_attach() -> void:
    var old := get_node_or_null("FirstCycleSpotlight")
    if old != null:
        remove_child(old)
        old.queue_free()
    if not _tutorial_active() or launch_gate_active or not v17_overlay.is_empty():
        return
    if not is_instance_valid(body):
        return
    var phase := str(GameState.state.get("phase", ""))
    # The roulette screen carries its own step label and motion; do not cover
    # the reel with the generic spotlight coach panel.
    if phase == "talent_reveal" and not bool(GameState.state.get("first_cycle_tutorial", {}).get("talent_roll_seen", false)):
        return
    # Dedicated preparation, offer, scouting and fight widgets handle their
    # own coaching without a floating panel covering actionable controls.
    if phase in ["fight_offer", "tactical_prep", "condition_prep", "game_plan", "fight"]:
        return
    var info: Dictionary = {
        "style_select": ["1/10 · 선수 스타일", "복싱 스타일을 비교한 뒤 원하는 카드를 선택하세요.", "BoxerStyle_balanced"],
        "talent_reveal": ["2/10 · 타고난 재능", "재능은 무작위로 정해집니다. 추첨 연출을 보고 결과를 확인하세요.", "RandomTalentContinue"],
        "camp": ["3/10 · 첫 훈련", "실제 훈련을 골라 능력치 변화를 확인하세요.", "TrainingSelect_sparring"],
        "fight_offer": ["5/10 · 첫 상대", "상대의 난이도와 보상을 비교하고 계약하세요.", "FightOfferSelect_*"],
        "tactical_prep": ["6/10 · 전술 준비", "상대의 습관에 맞춰 전술을 선택하세요.", "PreparationSelect_*"],
        "condition_prep": ["6/10 · 몸 상태", "피로와 체중을 확인하고 컨디션을 결정하세요.", "PreparationSelect_*"],
        "game_plan": ["7/10 · 경기 분석", "상대의 강점과 약점을 읽고 게임플랜으로 넘어가세요.", "ScoutingShowPlans"],
        "result": ["10/10 · 경기 정산", "전적, 파이트머니, 건강과 피로 변화를 확인하세요.", "FightResultContinue"],
    }
    if phase == "fight" and _needs_weigh_in_interstitial():
        info["fight"] = ["8/10 · 공식 계체", "체중 판정을 확인하고 실제 경기에 입장하세요.", "WeighInEnterFight"]
    elif phase == "fight":
        var action := _tutorial_next_action()
        if action.is_empty():
            return
        info["fight"] = ["9/10 · 경기 실전", "%s 공격을 직접 시도해보세요. 결과는 실제 전투로 계산됩니다." % {"jab":"잽", "guard":"가드", "body":"바디", "power":"파워", "counter":"카운터"}.get(action, action), "FightAction_" + action]
    if not info.has(phase):
        return
    var entry: Array = info[phase]
    if phase == "talent_reveal" and bool(GameState.state.get("first_cycle_tutorial", {}).get("talent_roll_seen", false)):
        entry = ["2/10 · 재능 확정", "선택한 재능과 능력치 보정을 확인하고 커리어를 시작하세요.", "BoxerBeginCareer"]
    if phase == "fight" and _needs_weigh_in_interstitial():
        entry = ["8/10 · 공식 계체", "체중 판정을 확인하고 실제 경기에 입장하세요.", "WeighInEnterFight"]
    var target := body.find_child(str(entry[2]), true, false) as Control
    if target == null:
        return
    var spotlight := FIRST_CYCLE_SPOTLIGHT.new()
    spotlight.focus = target
    spotlight.font = _v18_font(580)
    spotlight.step_title = str(entry[0])
    spotlight.instruction = str(entry[1])
    spotlight.skipped.connect(_skip_first_bout_guide)
    add_child(spotlight)
    spotlight.call_deferred("_position_dialogue")


func _review_panel(heading: String, report: Dictionary) -> void:
    var panel := _v17_panel(body, true)
    _v17_title(panel, heading, 21)
    _v17_copy(panel, "%d전 %d승 %d패 %d무 · 랭킹 #%d (%+d계단)" % [
        report.fights, report.wins, report.losses, report.draws, report.rank, report.rank_gain], false)
    _v17_copy(panel, "인기 %d (%+d) · %d경기 평균 능력치 %+.1f" % [
        report.fans, report.fan_gain, int(report.fights) - int(report.since), report.skill_gain], true)
    _v17_copy(panel, str(report.get("next_title", "")), false)
    var span := int(report.fights) - int(report.since)
    if span > 0:
        _v17_copy(panel, "성장 속도 · 경기당 평균 능력치 %+.2f" % (float(report.skill_gain) / span), true)
    _v17_copy(panel, "건강 %d · 부상 %s · 세계 타이틀 %s" % [
        report.health, report.injury, "도전 가능" if report.title_ready else "자격 준비 중"], true)
    if report.has("total_attendance"):
        _v17_copy(panel, "누적 관중 %s명 · 흥행 배분금 %s원 · 스폰서 수익 %s원" % [
            str(int(report.total_attendance)), _v17_money(int(report.total_gate_income)),
            _v17_money(int(report.total_sponsor_income))], true)

func _render_sponsorship_decision() -> void:
    var status: Dictionary = GameState.sponsorship_status()
    var offers: Array = GameState.sponsorship_offers()
    var first_offer: bool = int(GameState.state.career_state.business_state.get("sponsor_decision_fights", -1)) < 0
    _v17_section_heading("첫 공식 스폰서 제안!" if first_offer else "스폰서 재계약", "타이틀로 가능한 브랜드 등급이, 인지도로 계약 조건이 결정됩니다.")
    _v17_copy(body, "다음 실제 경기부터 4경기 계약입니다. 안정형과 KO 보너스 중심의 성과형 중 선택하세요.", true)
    for offer: Dictionary in offers.slice(0, 2):
        var id := str(offer.get("id", ""))
        var section := _v17_panel(body, false)
        section.add_theme_constant_override("separation", 9)
        var sponsor_title := _v17_title(section, str(offer.get("name", "스폰서")), 20)
        sponsor_title.add_theme_color_override("font_color", V17_GOLD)
        for contract_style: String in ["steady", "performance"]:
            var lost: Dictionary = GameState.Business.payment_for_style(offer, contract_style, "LOSS_DEC")
            var won: Dictionary = GameState.Business.payment_for_style(offer, contract_style, "WIN_DEC")
            var ko: Dictionary = GameState.Business.payment_for_style(offer, contract_style, "WIN_KO")
            var label := "%s · 패배 %s원\n판정승 %s원 · KO승 %s원" % [
                "안정형" if contract_style == "steady" else "성과형",
                _v17_money(int(lost.total)), _v17_money(int(won.total)), _v17_money(int(ko.total))]
            var button := _v17_gold_button(label)
            button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            button.custom_minimum_size.y = 70
            button.name = "Sponsor_" + id + "_" + contract_style
            button.pressed.connect(Callable(self, "_choose_sponsor").bind(id, contract_style))
            section.add_child(button)
    var next_tier: Dictionary = status.get("next_tier", {})
    if not next_tier.is_empty():
        _v17_copy(body, "상위 스폰서: %s 타이틀 · 인지도 %d 필요 (현재 %d)" % [
            str(next_tier.get("title_label", "")), int(next_tier.get("minimum_reputation", 0)),
            int(GameState.state.career.reputation)], true)
    var decline := _v17_dark_button("이번에는 계약하지 않기")
    decline.name = "Sponsor_decline"
    decline.pressed.connect(_decline_sponsor)
    body.add_child(decline)

func _choose_sponsor(sponsor_id: String, contract_style: String) -> void:
    if GameState.sign_sponsorship(sponsor_id, contract_style):
        _render_phase()
        _reset_reference_scroll()

func _decline_sponsor() -> void:
    if GameState.decline_sponsorship():
        _render_phase()
        _reset_reference_scroll()

func _render_career_decision() -> void:
    var c: Dictionary = GameState.state.career
    if GameState.state.phase == "champion_choice":
        _v17_section_heading("세계 챔피언", "방어전 %d / 3회 · 다음 경기에 도전하거나 지금 은퇴할 수 있습니다." % int(GameState.state.career_state.defenses))
        for defend: bool in [true, false]:
            var button := _v17_gold_button("방어전 준비" if defend else "챔피언으로 은퇴")
            button.pressed.connect(func():
                if GameState.champion_decision(defend):
                    _render_phase()
            )
            body.add_child(button)
        return
    _review_panel("시즌 %d 평가" % (int(c.fights) / 4), GameState.season_review())
    if int(c.fights) == 12 and GameState.state.career_state.has("milestone"):
        _review_panel("12전 커리어 평가", GameState.state.career_state.milestone)
    var sponsorship: Dictionary = GameState.sponsorship_status()
    if bool(sponsorship.get("active", false)):
        var active: Dictionary = sponsorship.get("sponsor", {})
        _v17_section_heading("진행 중 스폰서", "%s · %d경기 남음" % [str(active.get("name", "")), int(active.get("remaining_fights", 0))])
    _v17_section_heading("다음 네 경기 계약", "랭킹을 반영한 파이트머니입니다. 계체 결과와 경기 비용은 정산 때 반영됩니다.")
    var choices := VBoxContainer.new()
    choices.name = "SeasonContractChoices"
    choices.add_theme_constant_override("separation", 10)
    body.add_child(choices)
    for id: String in GameState.League.CONTRACTS:
        var contract: Dictionary = GameState.League.CONTRACTS[id]
        var rate := roundi(GameState.League.contract_rate(GameState.state, id) * 100)
        var panel := _v17_panel(choices, false)
        panel.add_theme_constant_override("separation", 7)
        var headline := VBoxContainer.new()
        headline.add_theme_constant_override("separation", 2)
        panel.add_child(headline)
        var name_label := _v17_title(headline, str(contract.name), 19)
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var multiplier := _v17_title(headline, "파이트머니 배율 %d%%" % rate, 18)
        multiplier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        multiplier.add_theme_color_override("font_color", V17_GOLD)
        _v17_copy(panel, str(contract.detail), true)
        var button := _v17_gold_button("이 계약 선택")
        button.name = "Contract_" + id
        button.custom_minimum_size.y = 48
        button.pressed.connect(func():
            if GameState.sign_contract(id):
                _render_phase()
        )
        panel.add_child(button)
