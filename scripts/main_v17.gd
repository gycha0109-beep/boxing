extends "res://scripts/main_v16.gd"

const V17_BG := Color(0.015, 0.023, 0.034, 1.0)
const V17_PANEL := Color(0.025, 0.045, 0.067, 0.985)
const V17_PANEL_2 := Color(0.035, 0.060, 0.086, 0.985)
const V17_PANEL_SOFT := Color(0.045, 0.075, 0.105, 0.94)
const V17_BORDER := Color(0.17, 0.25, 0.34, 1.0)
const V17_GOLD := Color(0.94, 0.69, 0.28, 1.0)
const V17_GOLD_SOFT := Color(0.67, 0.48, 0.20, 1.0)
const V17_TEXT := Color(0.94, 0.95, 0.97, 1.0)
const V17_MUTED := Color(0.62, 0.67, 0.73, 1.0)
const V17_DANGER := Color(0.93, 0.31, 0.31, 1.0)
const V17_SUCCESS := Color(0.29, 0.78, 0.58, 1.0)
const V17_BLUE := Color(0.25, 0.63, 0.96, 1.0)
const V17_HP := Color(0.91, 0.20, 0.25, 1.0)


var v17_money_label: Label
var v17_nav_buttons: Dictionary = {}
var v17_overlay: String = ""
var v17_manage_expanded: bool = false

func _build_shell() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = V17_BG
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 8)
    add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 0)
    margin.add_child(root)
    root.add_child(_v17_top_bar())
    header = Label.new()
    header.visible = false
    root.add_child(header)
    status = Label.new()
    status.visible = false
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(status)
    var divider := HSeparator.new()
    divider.add_theme_constant_override("separation", 0)
    root.add_child(divider)
    var scroll := ScrollContainer.new()
    scroll.name = "V17ContentScroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.scroll_deadzone = 6
    root.add_child(scroll)
    var content_margin := MarginContainer.new()
    content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_margin.add_theme_constant_override("margin_top", 10)
    content_margin.add_theme_constant_override("margin_bottom", 14)
    scroll.add_child(content_margin)
    body = VBoxContainer.new()
    body.name = "V17Body"
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 10)
    content_margin.add_child(body)
    root.add_child(_v17_bottom_nav())

func _ready() -> void:
    super._ready()
    _v17_sync_nav()

func _render_status() -> void:
    if GameState == null or GameState.state.is_empty():
        if is_instance_valid(v17_money_label): v17_money_label.text = "0원"
        return
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    status.text = "%s · #%d · %d-%d-%d" % [str(boxer.get("name", "BOXER")), int(career.get("rank", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0))]
    if is_instance_valid(v17_money_label): v17_money_label.text = "%s원" % _v17_money(int(career.get("money", 0)))

func _render_phase() -> void:
    if not v17_overlay.is_empty() and not launch_gate_active:
        fighter_profile_root = null
        _clear_body()
        _render_status()
        match v17_overlay:
            "profile": _v17_render_profile_home()
            "career": _v17_render_career_home()
            "shop": _v17_render_shop_hint()
            _: v17_overlay = ""
        _configure_mobile_scroll()
        _v17_sync_nav()
        _sync_music_for_phase()
        call_deferred("_wire_ui_sounds")
        return
    super._render_phase()
    _v17_sync_nav()

func _should_insert_persistent_fighter_profile() -> bool:
    return false

func _render_camp() -> void:
    _v17_player_hero("훈련 캠프 선택", "땀은 배신하지 않는다.")
    _v17_section_heading("훈련 캠프 선택", "이번 캠프에서는 한 가지 성장에 집중합니다.")
    var core_ids := ["mitts", "roadwork", "heavy_bag", "defense_drill"]
    var grid := _v17_grid(2)
    for action_value in camp_actions:
        var action: Dictionary = action_value
        if str(action.get("id", "")) in core_ids: _v17_training_card(grid, action)
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
            if str(action.get("id", "")) not in core_ids: _v17_training_card(management, action)
    var shop := _v17_secondary_button("장비 · 체육관 투자  ›")
    shop.pressed.connect(Callable(self, "_open_equipment_shop"))
    body.add_child(shop)

func _render_offers() -> void:
    _v17_offer_hero()
    var offers: Array = GameState.get_fight_offers(opponents)
    var index := 0
    for opponent_value in offers:
        _v17_opponent_contract(opponent_value as Dictionary, index == 0)
        index += 1
    _v17_career_progress_strip()

func _render_tactical_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v17_matchup_strip("전술 준비", "상대의 습관에 맞춰 한 가지 흐름을 준비합니다.")
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

func _render_condition_preparation() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v17_matchup_strip("경기 주간 준비", "최상의 컨디션으로 승리를 준비하세요.")
    _v17_section_heading("이번 주, 어떤 준비를 하시겠습니까?", "지금의 준비가 링 위의 차이를 만듭니다.")
    var grid := _v17_grid(2)
    for prep_value in GameState.condition_preparations():
        var prep: Dictionary = prep_value
        var card := _v17_panel(grid, false)
        _v17_prep_symbol(card, str(prep.get("id", "")))
        _v17_title(card, str(prep.get("name", "준비")), 19)
        _v17_copy(card, _v16_one_line(str(prep.get("description", "")), 58), true)
        _v17_condition_chips(card, prep)
        var choose := _v17_gold_button("이 준비 선택하기  →")
        choose.pressed.connect(Callable(self, "_choose_condition_preparation").bind(str(prep.get("id", ""))))
        card.add_child(choose)
    var back := _v17_secondary_button("← 전술 준비 다시 선택")
    back.pressed.connect(Callable(self, "_return_to_tactical_preparation"))
    body.add_child(back)

func _render_game_plan() -> void:
    _sync_current_opponent()
    if current_opponent.is_empty():
        GameState.state["phase"] = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return
    _v17_matchup_strip("게임플랜", "상대의 강점과 약점을 읽고 한 가지 플랜을 고릅니다.")
    var scouting: Dictionary = current_opponent.get("scouting", {})
    var scouting_box := _v17_panel(body, false)
    _v17_eyebrow(scouting_box, "상대 분석")
    _v17_title(scouting_box, "SCOUTING READ", 18)
    _v17_copy(scouting_box, "강점 · %s" % str(scouting.get("strength", "정보 부족")), false)
    _v17_copy(scouting_box, "약점 · %s" % str(scouting.get("weakness", "정보 부족")), true)
    var suggested: Array = scouting.get("suggested_plans", [])
    var grid := _v17_grid(2)
    for plan_value in GameState.game_plans:
        var plan: Dictionary = plan_value
        var recommended: bool = str(plan.get("id", "")) in suggested
        var card := _v17_panel(grid, recommended)
        _v17_title(card, ("★ " if recommended else "") + str(plan.get("name", "플랜")), 18)
        _v17_chip(card, "리스크 · %s" % str(plan.get("risk", "중간")), V17_DANGER if str(plan.get("risk", "")) == "높음" else V17_MUTED)
        _v17_copy(card, _v16_one_line(str(plan.get("description", "")), 52), true)
        _v17_copy(card, _v16_one_line(_plan_effect_text(plan), 48), false)
        var choose := _v17_gold_button("이 플랜 선택") if recommended else _v17_dark_button("이 플랜 선택")
        choose.pressed.connect(Callable(self, "_choose_game_plan").bind(str(plan.get("id", ""))))
        card.add_child(choose)
    var condition_back := _v17_secondary_button("← 컨디션 다시 선택")
    condition_back.pressed.connect(Callable(self, "_return_to_condition_preparation"))
    body.add_child(condition_back)
    var opponent_back := _v17_secondary_button("← 상대 다시 선택")
    opponent_back.pressed.connect(Callable(self, "_return_to_fight_offers"))
    body.add_child(opponent_back)

func _render_weigh_in() -> void:
    _clear_body()
    _render_status()
    if current_opponent.is_empty(): current_opponent = _find_opponent(str(GameState.state.get("selected_opponent", "")))
    if current_opponent.is_empty():
        GameState.state["weigh_in_acknowledged"] = true
        SaveService.save_game(GameState.state)
        super._render_phase()
        return
    var back := _v17_secondary_button("← 게임플랜 다시 선택")
    back.pressed.connect(Callable(self, "_return_to_game_plan_selection"))
    body.add_child(back)
    _v17_eyebrow(body, "FIGHT WEEK · OFFICIAL WEIGH-IN")
    _v17_title(body, "공식 계체", 30)
    var matchup := _v17_panel(body, false)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    matchup.add_child(row)
    _v17_weigh_fighter(row, VisualAssetCatalog.identity_portrait_texture(true), str(GameState.state.boxer.get("name", "BOXER")), "KR")
    var vs := Label.new()
    vs.text = "VS"
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs.add_theme_font_size_override("font_size", 20)
    vs.add_theme_color_override("font_color", V17_GOLD)
    vs.custom_minimum_size = Vector2(40, 0)
    row.add_child(vs)
    _v17_weigh_fighter(row, _v17_opponent_texture(current_opponent), _v17_opponent_name(current_opponent), _v17_country(current_opponent))
    var weigh_in: Dictionary = GameState.state.get("last_weigh_in", {})
    var status_id := str(weigh_in.get("status", "pass"))
    var limit := float(GameState.career_balance.weight_class.limit_kg)
    var boxer_weight := float(GameState.state.boxer.get("weight_kg", limit))
    var verdict := Label.new()
    verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    verdict.add_theme_font_size_override("font_size", 26)
    match status_id:
        "emergency_cut": verdict.text = "긴급 감량 통과"; verdict.add_theme_color_override("font_color", V17_GOLD)
        "miss": verdict.text = "계체 실패"; verdict.add_theme_color_override("font_color", V17_DANGER)
        _: verdict.text = "계체 통과"; verdict.add_theme_color_override("font_color", V17_SUCCESS)
    body.add_child(verdict)
    var weight := Label.new()
    weight.text = "%.2f KG  /  LIMIT %.1f KG" % [boxer_weight, limit]
    weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weight.add_theme_font_size_override("font_size", 18)
    body.add_child(weight)
    var plan := GameState.get_selected_game_plan()
    var plan_box := _v17_panel(body, false)
    _v17_eyebrow(plan_box, "확정된 게임플랜")
    _v17_title(plan_box, str(plan.get("name", "균형 운영")), 19)
    _v17_copy(plan_box, str(plan.get("description", "")), true)
    var enter := _v17_gold_button("FIGHT NIGHT 입장")
    enter.custom_minimum_size.y = 66
    enter.pressed.connect(Callable(self, "_acknowledge_weigh_in"))
    body.add_child(enter)

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    fighter_profile_root = null
    _clear_body()
    _render_status()
    body.add_theme_constant_override("separation", 7)
    var had_pending_action: bool = not combat.pending_opponent_action.is_empty()
    var telegraph: Dictionary = combat.prepare_exchange()
    if not had_pending_action and not telegraph.is_empty(): GameState.save_active_fight(combat.export_state())
    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    var exchange_in_round: int = (int(snap.exchange) % int(combat.balance.fight.exchanges_per_round)) + 1
    var round_bar := _v17_panel(body, true)
    var round_row := HBoxContainer.new()
    round_row.add_theme_constant_override("separation", 8)
    round_bar.add_child(round_row)
    var round_label := Label.new()
    round_label.text = "ROUND %d / 3" % int(snap.round)
    round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    round_label.add_theme_font_size_override("font_size", 17)
    round_label.add_theme_color_override("font_color", V17_GOLD)
    round_row.add_child(round_label)
    var exchange_label := Label.new()
    exchange_label.text = "EXCHANGE %d / %d" % [exchange_in_round, int(combat.balance.fight.exchanges_per_round)]
    exchange_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    exchange_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    exchange_label.add_theme_font_size_override("font_size", 15)
    round_row.add_child(exchange_label)
    var plan_label := Label.new()
    plan_label.text = str(selected_plan.get("name", "균형 운영"))
    plan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    plan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    plan_label.add_theme_font_size_override("font_size", 13)
    plan_label.add_theme_color_override("font_color", V17_MUTED)
    round_row.add_child(plan_label)
    var stage := FightStage.new()
    stage.configure(str(GameState.state.boxer.get("name", "BOXER")), _v17_opponent_name(current_opponent), snap, telegraph)
    stage.opponent_style = _v17_visual_style(current_opponent)
    stage.title_fight = bool(current_opponent.get("title_fight", false))
    stage.custom_minimum_size = Vector2(0, 330)
    body.add_child(stage)
    if not animated_exchange.is_empty(): stage.play_exchange(animated_exchange)
    var hud := _v17_panel(body, false)
    var hud_row := HBoxContainer.new()
    hud_row.add_theme_constant_override("separation", 10)
    hud.add_child(hud_row)
    _v17_fighter_hud(hud_row, str(GameState.state.boxer.get("name", "BOXER")), "KR", float(snap.player_hp), float(snap.player_stamina), false)
    var vs_hud := Label.new()
    vs_hud.text = "VS"
    vs_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs_hud.custom_minimum_size = Vector2(36, 0)
    vs_hud.add_theme_font_size_override("font_size", 19)
    vs_hud.add_theme_color_override("font_color", V17_GOLD)
    hud_row.add_child(vs_hud)
    _v17_fighter_hud(hud_row, _v17_opponent_name(current_opponent), _v17_country(current_opponent), float(snap.opponent_hp), float(snap.opponent_stamina), true)
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
    var read := _v17_panel(body, false)
    var read_row := HBoxContainer.new()
    read_row.add_theme_constant_override("separation", 10)
    read.add_child(read_row)
    var read_left := VBoxContainer.new()
    read_left.custom_minimum_size = Vector2(82, 0)
    read_row.add_child(read_left)
    _v17_copy(read_left, "상황 분석", true)
    var bulb := Label.new()
    bulb.text = "◉"
    bulb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bulb.add_theme_font_size_override("font_size", 22)
    bulb.add_theme_color_override("font_color", V17_GOLD)
    read_left.add_child(bulb)
    var read_mid := VBoxContainer.new()
    read_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    read_row.add_child(read_mid)
    _v17_title(read_mid, "OPPONENT READ · %d%%" % int(telegraph.get("confidence", 0)), 15)
    _v17_copy(read_mid, CombatPresentation.telegraph_title(telegraph), false)
    _v17_copy(read_mid, _compact_read_hint(str(telegraph.get("action_id", ""))), true)
    var rec := VBoxContainer.new()
    rec.custom_minimum_size = Vector2(112, 0)
    read_row.add_child(rec)
    _v17_copy(rec, "추천 공략", true)
    _v17_copy(rec, _v17_recommendation(str(telegraph.get("action_id", ""))), false)
    var action_grid := _v17_grid(3)
    for action_id in V05_ACTION_IDS: _v17_fight_action(action_grid, action_id, selected_plan)
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 78)
    action_grid.add_child(spacer)
    _configure_mobile_scroll()

func _render_result() -> void:
    var summary: Dictionary = GameState.state.get("last_fight_summary", {})
    var result_id := str(summary.get("result", GameState.state.get("last_result", "")))
    var win := result_id.begins_with("WIN")
    _v17_player_hero("경기 결과", "오늘의 결과가 다음 커리어를 만듭니다.")
    var hero := _v17_panel(body, true)
    var result := Label.new()
    result.text = _result_label(result_id)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", 34)
    result.add_theme_color_override("font_color", V17_SUCCESS if win else V17_DANGER)
    hero.add_child(result)
    _v17_copy(hero, "vs %s" % _v17_summary_opponent_name(summary), true)
    var career: Dictionary = GameState.state.get("career", {})
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var update := _v17_panel(body, false)
    _v17_eyebrow(update, "CAREER UPDATE")
    _v17_copy(update, "%d전 %d승 %d패 %d무 · 랭킹 #%d · 커리어 %dpt" % [int(career.get("fights", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), int(career.get("rank", 0)), int(career.get("career_points", 0))], false)
    _v17_copy(update, "건강 %d%% · 피로 %d%% · 체중 %.1fkg" % [int(boxer.get("health", 0)), int(boxer.get("fatigue", 0)), float(boxer.get("weight_kg", 0.0))], true)
    var next := _v17_gold_button("커리어 계속")
    next.pressed.connect(func(): GameState.advance_after_result(); current_opponent = {}; _render_phase())
    body.add_child(next)

func _v16_stat_row(parent: VBoxContainer, stat_id: String, value: int) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 7)
    parent.add_child(row)
    var label := Label.new()
    label.text = _stat_label(stat_id)
    label.custom_minimum_size = Vector2(74, 0)
    label.add_theme_font_size_override("font_size", 14)
    row.add_child(label)
    var help := Button.new()
    help.text = "?"
    help.flat = true
    help.tooltip_text = GameState.stat_help(stat_id)
    help.custom_minimum_size = Vector2(44, 44)
    help.name = "StatHelp_" + stat_id
    help.add_theme_font_size_override("font_size", 12)
    help.add_theme_color_override("font_color", V17_MUTED)
    help.add_theme_stylebox_override("normal", _v17_circle_style(Color(0.035, 0.055, 0.075, 1.0), V17_BORDER))
    help.add_theme_stylebox_override("hover", _v17_circle_style(Color(0.05, 0.08, 0.11, 1.0), V17_GOLD_SOFT))
    help.mouse_filter = Control.MOUSE_FILTER_PASS
    help.pressed.connect(Callable(self, "_show_stat_help").bind(stat_id))
    row.add_child(help)
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = clampi(value, 0, 100)
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 10)
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.10, 0.14, 0.19, 1.0)
    bg.set_corner_radius_all(5)
    var fill := StyleBoxFlat.new()
    fill.bg_color = V17_BLUE if stat_id == "speed" else V17_GOLD
    fill.set_corner_radius_all(5)
    bar.add_theme_stylebox_override("background", bg)
    bar.add_theme_stylebox_override("fill", fill)
    row.add_child(bar)
    var number := Label.new()
    number.text = str(value)
    number.custom_minimum_size = Vector2(28, 0)
    number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    number.add_theme_font_size_override("font_size", 15)
    row.add_child(number)

func _v17_top_bar() -> Control:
    var bar := PanelContainer.new()
    bar.custom_minimum_size = Vector2(0, 72)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.015, 0.025, 0.038, 0.98)
    style.content_margin_left = 4
    style.content_margin_right = 4
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    bar.add_theme_stylebox_override("panel", style)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    bar.add_child(row)
    var menu := Button.new()
    menu.text = "☰"
    menu.flat = true
    menu.custom_minimum_size = Vector2(44, 54)
    menu.add_theme_font_size_override("font_size", 26)
    menu.add_theme_color_override("font_color", V17_GOLD)
    row.add_child(menu)
    var brand := VBoxContainer.new()
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_child(brand)
    var crown := Label.new()
    crown.text = "♛"
    crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crown.add_theme_font_size_override("font_size", 14)
    crown.add_theme_color_override("font_color", V17_GOLD)
    brand.add_child(crown)
    var logo := Label.new()
    logo.text = "TWELVE COUNT"
    logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    logo.add_theme_font_size_override("font_size", 22)
    logo.add_theme_color_override("font_color", V17_GOLD)
    brand.add_child(logo)
    var sub := Label.new()
    sub.text = "B O X I N G   C A R E E R"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 8)
    sub.add_theme_color_override("font_color", V17_GOLD_SOFT)
    brand.add_child(sub)
    var money_box := PanelContainer.new()
    money_box.custom_minimum_size = Vector2(94, 42)
    money_box.add_theme_stylebox_override("panel", _v17_box_style(Color(0.025, 0.045, 0.065, 1.0), V17_BORDER, 18, 7))
    row.add_child(money_box)
    v17_money_label = Label.new()
    v17_money_label.text = "0원"
    v17_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v17_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    v17_money_label.add_theme_font_size_override("font_size", 13)
    money_box.add_child(v17_money_label)
    var gear := Button.new()
    gear.text = "⚙"
    gear.flat = true
    gear.custom_minimum_size = Vector2(42, 54)
    gear.add_theme_font_size_override("font_size", 24)
    gear.add_theme_color_override("font_color", V17_MUTED)
    row.add_child(gear)
    return bar

func _v17_bottom_nav() -> Control:
    var nav := PanelContainer.new()
    nav.custom_minimum_size = Vector2(0, 72)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.031, 0.046, 0.995)
    style.border_color = Color(0.11, 0.16, 0.22, 1.0)
    style.border_width_top = 1
    style.content_margin_top = 4
    nav.add_theme_stylebox_override("panel", style)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 2)
    nav.add_child(row)
    _v17_nav_button(row, "profile", "●\n내 선수", Callable(self, "_v17_open_overlay").bind("profile"))
    _v17_nav_button(row, "match", "◆\n경기", Callable(self, "_v17_open_match"))
    _v17_nav_button(row, "training", "▥\n트레이닝", Callable(self, "_v17_open_training"))
    _v17_nav_button(row, "career", "♛\n커리어", Callable(self, "_v17_open_overlay").bind("career"))
    _v17_nav_button(row, "shop", "▣\n상점", Callable(self, "_v17_open_shop"))
    return nav

func _v17_nav_button(parent: HBoxContainer, key: String, text_value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 64)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.add_theme_font_size_override("font_size", 11)
    button.pressed.connect(callback)
    parent.add_child(button)
    v17_nav_buttons[key] = button

func _v17_sync_nav() -> void:
    var active := "match"
    if not v17_overlay.is_empty(): active = v17_overlay if v17_overlay in ["profile", "career", "shop"] else "match"
    elif not GameState.state.is_empty():
        var phase := str(GameState.state.get("phase", ""))
        if phase in ["camp", "equipment_shop", "style_select", "talent_reveal"]: active = "training"
        elif phase in ["fight_offer", "tactical_prep", "condition_prep", "game_plan", "fight", "result"]: active = "match"
    for key in v17_nav_buttons.keys():
        var button: Button = v17_nav_buttons[key]
        var selected := str(key) == active
        button.add_theme_color_override("font_color", V17_GOLD if selected else V17_MUTED)
        button.add_theme_stylebox_override("normal", _v17_nav_style(selected))
        button.add_theme_stylebox_override("pressed", _v17_nav_style(true))
        button.add_theme_stylebox_override("hover", _v17_nav_style(selected))

func _v17_open_overlay(key: String) -> void:
    v17_overlay = key
    _render_phase()
func _v17_open_match() -> void:
    v17_overlay = ""
    _render_phase()
func _v17_open_training() -> void:
    v17_overlay = ""
    if str(GameState.state.get("phase", "")) == "camp": _render_phase(); return
    _clear_body(); _render_status(); _v17_section_heading("트레이닝", "현재 경기 사이클을 마친 뒤 다음 캠프에서 다시 훈련할 수 있습니다."); _v17_sync_nav()
func _v17_open_shop() -> void:
    if str(GameState.state.get("phase", "")) == "camp": v17_overlay = ""; _open_equipment_shop(); return
    v17_overlay = "shop"; _render_phase()

func _v17_render_profile_home() -> void:
    _v17_player_hero("내 선수", "더 높은 곳을 향한 카운트는 아직 끝나지 않았다.")
    var stage: Dictionary = GameState.career_ladder_stage()
    var career_box := _v17_panel(body, false)
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); career_box.add_child(row)
    var medal := Label.new(); medal.text = "◉"; medal.custom_minimum_size = Vector2(56, 56); medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; medal.add_theme_font_size_override("font_size", 34); medal.add_theme_color_override("font_color", V17_GOLD); row.add_child(medal)
    var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
    _v17_eyebrow(info, "CAREER"); _v17_title(info, str(stage.get("label", "동네 신인")), 24); _v17_copy(info, "작은 링에서, 더 큰 꿈을 향해.", true)
    var stat_box := _v17_panel(body, false); _v17_title(stat_box, "능력치", 23)
    var boxer: Dictionary = GameState.state.get("boxer", {})
    for stat_id in ["power", "speed", "technique", "defense", "conditioning"]: _v16_stat_row(stat_box, stat_id, int(boxer.get(stat_id, 0)))
    var two := _v17_grid(2)
    var state_box := _v17_panel(two, false); _v17_title(state_box, "현재 상태", 19); _v17_copy(state_box, "컨디션 · %s" % ("경기 준비 중" if int(boxer.get("fatigue", 0)) < 90 else "회복 필요"), false); _v17_copy(state_box, "피로도 · %d%%" % int(boxer.get("fatigue", 0)), int(boxer.get("fatigue", 0)) > 70)
    var injury: Dictionary = boxer.get("injury", {}); _v17_copy(state_box, "부상 · %s" % ("없음" if injury.is_empty() else str(injury.get("name", "부상"))), true)
    var style_box := _v17_panel(two, false); _v17_title(style_box, "스타일", 19); _v17_copy(style_box, "복싱 스타일 · %s" % str(boxer.get("identity_name", "균형형")), false); _v17_copy(style_box, "타고난 재능 · %s" % str(boxer.get("trait_name", "")), true); _v17_copy(style_box, "꾸준함이 가장 강한 무기다.", true)

func _v17_render_career_home() -> void:
    _v17_section_heading("커리어", "한 단계씩 타이틀 사다리를 올라갑니다.")
    _v17_career_progress_strip()
    var career: Dictionary = GameState.state.get("career", {})
    var summary := _v17_panel(body, false); _v17_title(summary, "커리어 기록", 22); _v17_copy(summary, "%d전 %d승 %d패 %d무 · 랭킹 #%d" % [int(career.get("fights", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), int(career.get("rank", 0))], false); _v17_copy(summary, "커리어 포인트 %dpt · 누적 수입 %s원" % [int(career.get("career_points", 0)), _v17_money(int(career.get("money", 0)))], true)
func _v17_render_shop_hint() -> void:
    _v17_section_heading("상점", "장비 투자는 캠프 단계에서 이용할 수 있습니다.")
    var box := _v17_panel(body, false); _v17_title(box, "다음 캠프에서 장비를 강화하세요", 21); _v17_copy(box, "개인 장비는 경기 능력치를 보완하고, 체육관 투자는 같은 훈련의 성장 효율을 높입니다.", true)

func _v17_player_hero(section_title: String, quote: String) -> void:
    var hero := _v17_panel(body, false)
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); hero.add_child(row)
    var portrait := TextureRect.new(); portrait.texture = VisualAssetCatalog.portrait_texture(true); portrait.custom_minimum_size = Vector2(142, 178); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; portrait.clip_contents = true; portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(portrait)
    var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation", 4); row.add_child(right)
    _v17_eyebrow(right, "TWELVE COUNT · BOXING CAREER")
    var boxer: Dictionary = GameState.state.get("boxer", {}); var career: Dictionary = GameState.state.get("career", {})
    _v17_title(right, str(boxer.get("name", "BOXER")), 26)
    _v17_copy(right, "%s #%d  |  %d승 %d패 %d무  |  %s" % [GameState.tier_label(), int(career.get("rank", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), GameState.age_text()], false)
    _v17_copy(right, quote, true); _v17_copy(right, section_title, false); _v17_metrics(right)

func _v17_offer_hero() -> void:
    var hero := _v17_panel(body, false); var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); hero.add_child(row)
    var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(left)
    _v17_eyebrow(left, "경기"); _v17_title(left, "다음 상대를 선택하세요", 28); _v17_copy(left, "더 강한 상대와 싸울수록, 전설에 가까워집니다.", true)
    var portrait := TextureRect.new(); portrait.texture = VisualAssetCatalog.portrait_texture(true); portrait.custom_minimum_size = Vector2(118, 138); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; portrait.clip_contents = true; row.add_child(portrait)

func _v17_matchup_strip(title_text: String, subtitle: String) -> void:
    _v17_section_heading(title_text, subtitle)
    var panel := _v17_panel(body, false); var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); panel.add_child(row)
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var player := VBoxContainer.new(); player.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(player); _v17_eyebrow(player, "내 선수"); _v17_title(player, str(boxer.get("name", "BOXER")), 18); _v17_copy(player, "체중 %.1fkg · 피로 %d%% · 건강 %d%%" % [float(boxer.get("weight_kg", 0.0)), int(boxer.get("fatigue", 0)), int(boxer.get("health", 0))], true)
    row.add_child(VSeparator.new())
    var opp := VBoxContainer.new(); opp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(opp); _v17_eyebrow(opp, "다음 상대"); _v17_title(opp, "%s [%s]" % [_v17_opponent_name(current_opponent), _v17_country(current_opponent)], 18); _v17_copy(opp, "%s · #%d" % [_style_label(str(current_opponent.get("style", ""))), int(current_opponent.get("rank", 0))], true)

func _v17_metrics(parent: VBoxContainer) -> void:
    var boxer: Dictionary = GameState.state.get("boxer", {}); var career: Dictionary = GameState.state.get("career", {})
    var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 5); grid.add_theme_constant_override("v_separation", 5); parent.add_child(grid)
    _v17_metric(grid, "체중", "%.1fkg" % float(boxer.get("weight_kg", 0.0)), V17_TEXT); _v17_metric(grid, "피로", "%d%%" % int(boxer.get("fatigue", 0)), V17_DANGER if int(boxer.get("fatigue", 0)) > 65 else V17_TEXT); _v17_metric(grid, "건강", "%d%%" % int(boxer.get("health", 0)), V17_GOLD); _v17_metric(grid, "보유금", "%s원" % _v17_money(int(career.get("money", 0))), V17_TEXT)
func _v17_metric(parent: GridContainer, label_text: String, value: String, color: Color) -> void:
    var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 1); parent.add_child(box)
    var label := Label.new(); label.text = label_text; label.add_theme_font_size_override("font_size", 10); label.add_theme_color_override("font_color", V17_MUTED); box.add_child(label)
    var val := Label.new(); val.text = value; val.add_theme_font_size_override("font_size", 13); val.add_theme_color_override("font_color", color); box.add_child(val)

func _v17_training_card(parent: GridContainer, action: Dictionary) -> void:
    var affordable := int(GameState.state.get("career", {}).get("money", 0)) >= int(action.get("cost", 0))
    var card := _v17_panel(parent, false); _v17_training_art(card, str(action.get("id", ""))); _v17_title(card, _v17_training_name(action), 18); _v17_copy(card, _v17_training_description(str(action.get("id", ""))), true)
    var meta := HBoxContainer.new(); meta.add_theme_constant_override("separation", 6); card.add_child(meta); _v17_chip(meta, "비용 %s원" % _v17_money(int(action.get("cost", 0))), V17_TEXT); _v17_chip(meta, "부상 %.1f%%" % (float(action.get("risk", 0.0)) * 100.0), V17_DANGER if float(action.get("risk", 0.0)) >= 0.07 else V17_MUTED)
    _v17_effect_grid(card, action.get("effects", {}))
    var choose := _v17_gold_button("캠프 선택  ›") if affordable else _v17_dark_button("자금 부족"); choose.disabled = not affordable; choose.pressed.connect(Callable(self, "_choose_camp_action").bind(action)); card.add_child(choose)

func _v17_training_art(parent: VBoxContainer, action_id: String) -> void:
    var art := Control.new(); art.custom_minimum_size = Vector2(0, 88); art.clip_contents = true; parent.add_child(art)
    var arena := TextureRect.new(); arena.texture = VisualAssetCatalog.arena_texture(false); arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; arena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; arena.modulate = Color(0.55, 0.58, 0.62, 0.55); arena.mouse_filter = Control.MOUSE_FILTER_IGNORE; art.add_child(arena)
    var shade := ColorRect.new(); shade.color = Color(0.01, 0.02, 0.03, 0.28); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; art.add_child(shade)
    var fighter := TextureRect.new(); fighter.texture = VisualAssetCatalog.fighter_texture(true, "", _v17_training_pose(action_id)); fighter.anchor_left = 0.42; fighter.anchor_top = 0.02; fighter.anchor_right = 0.98; fighter.anchor_bottom = 1.0; fighter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fighter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; fighter.mouse_filter = Control.MOUSE_FILTER_IGNORE; art.add_child(fighter)
    var symbol := Label.new(); symbol.text = _v17_training_symbol(action_id); symbol.position = Vector2(10, 10); symbol.add_theme_font_size_override("font_size", 25); symbol.add_theme_color_override("font_color", V17_GOLD); symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE; art.add_child(symbol)

func _v17_effect_grid(parent: VBoxContainer, effects_value: Variant) -> void:
    var effects: Dictionary = effects_value if typeof(effects_value) == TYPE_DICTIONARY else {}; var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 4); grid.add_theme_constant_override("v_separation", 4); parent.add_child(grid)
    var order := ["power", "speed", "technique", "defense", "conditioning", "fatigue", "health", "weight", "injury_camps"]; var labels := {"power":"파워", "speed":"스피드", "technique":"테크닉", "defense":"수비", "conditioning":"체력", "fatigue":"피로", "health":"건강", "weight":"체중", "injury_camps":"재활"}; var count := 0
    for key in order:
        if not effects.has(key) or count >= 4: continue
        var value: float = float(effects[key]); var sign := "+" if value > 0 else ""; var text := "%s %s%.2fkg" % [labels[key], sign, value] if key == "weight" else "%s %s%d" % [labels[key], sign, int(value)]; _v17_chip(grid, text, V17_MUTED); count += 1

func _v17_opponent_contract(opponent: Dictionary, highlighted: bool) -> void:
    var card := _v17_panel(body, highlighted); var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); card.add_child(row)
    var portrait := TextureRect.new(); portrait.texture = _v17_opponent_texture(opponent); portrait.custom_minimum_size = Vector2(116, 154); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; portrait.clip_contents = true; portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(portrait)
    var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 4); row.add_child(info)
    _v17_title(info, "%s  %s" % [_v17_opponent_name(opponent), _v17_flag(_v17_country(opponent))], 21); _v17_copy(info, "%s · %s" % [_tier_label(str(opponent.get("tier", ""))), _style_label(str(opponent.get("style", "")))], false); _v17_copy(info, _v17_opponent_quote(opponent), true)
    var stats: Dictionary = opponent.get("stats", {}); _v17_copy(info, "파워 %d   스피드 %d   테크닉 %d" % [int(stats.get("power", 0)), int(stats.get("speed", 0)), int(stats.get("technique", 0))], false); _v17_copy(info, "수비 %d   체력 %d" % [int(stats.get("defense", 0)), int(stats.get("conditioning", 0))], true)
    var purse := Label.new(); purse.text = "파이트머니  %s원" % _v17_money(int(opponent.get("purse", 0))); purse.add_theme_font_size_override("font_size", 19); purse.add_theme_color_override("font_color", V17_GOLD); info.add_child(purse); _v17_copy(info, "승리 +%dpt  |  패배 -%dpt" % [int(opponent.get("career_points_win", 0)), abs(int(opponent.get("career_points_loss", 0)))], true)
    var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 6); info.add_child(actions)
    var analyze := _v17_dark_button("상대 분석"); analyze.size_flags_horizontal = Control.SIZE_EXPAND_FILL; analyze.pressed.connect(Callable(self, "_choose_opponent").bind(opponent)); actions.add_child(analyze)
    var accept := _v17_gold_button("도전 수락  ›"); accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL; accept.pressed.connect(Callable(self, "_choose_opponent").bind(opponent)); actions.add_child(accept)

func _v17_career_progress_strip() -> void:
    var stage: Dictionary = GameState.career_ladder_stage(); var next_stage: Dictionary = GameState.career_ladder_next_stage(); var career: Dictionary = GameState.state.get("career", {}); var panel := _v17_panel(body, false); _v17_eyebrow(panel, "CAREER LADDER · %s" % str(stage.get("label", "동네 신인")))
    if next_stage.is_empty(): _v17_title(panel, "세계 타이틀을 향한 마지막 단계", 18)
    else: _v17_title(panel, "다음 단계 · %s" % str(next_stage.get("label", "")), 18); _v17_copy(panel, "현재 %d전 %d승 · 필요 %d전 %d승" % [int(career.get("fights", 0)), int(career.get("wins", 0)), int(next_stage.get("min_fights", 0)), int(next_stage.get("min_wins", 0))], true)

func _v17_condition_chips(parent: VBoxContainer, prep: Dictionary) -> void:
    var effect := _v16_condition_effect(prep); var parts := effect.split(" · "); var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 5); parent.add_child(row)
    for part in parts.slice(0, 2): _v17_chip(row, str(part), V17_GOLD if "+" in str(part) else V17_SUCCESS)
func _v17_prep_symbol(parent: VBoxContainer, prep_id: String) -> void:
    var label := Label.new()
    match prep_id:
        "rest", "full_rest": label.text = "▰"
        "weight_control", "weight_cut": label.text = "◇"
        "sharpness": label.text = "↗"
        "hard_sparring", "sparring": label.text = "◆"
        _: label.text = "●"
    label.add_theme_font_size_override("font_size", 28); label.add_theme_color_override("font_color", V17_GOLD); parent.add_child(label)
func _v17_weigh_fighter(parent: HBoxContainer, texture: Texture2D, name_text: String, country: String) -> void:
    var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(col); var portrait := TextureRect.new(); portrait.texture = texture; portrait.custom_minimum_size = Vector2(0, 122); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; portrait.clip_contents = true; col.add_child(portrait); var name := Label.new(); name.text = "%s %s" % [name_text, _v17_flag(country)]; name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name.add_theme_font_size_override("font_size", 16); col.add_child(name)
func _v17_fighter_hud(parent: HBoxContainer, name_text: String, country: String, hp: float, stamina: float, right_align: bool) -> void:
    var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box); var name := Label.new(); name.text = "%s %s" % [name_text, _v17_flag(country)]; name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_align else HORIZONTAL_ALIGNMENT_LEFT; name.add_theme_font_size_override("font_size", 14); box.add_child(name); _v17_meter(box, "HP", hp, V17_HP); _v17_meter(box, "STA", stamina, V17_BLUE)
func _v17_meter(parent: VBoxContainer, label_text: String, value: float, fill_color: Color) -> void:
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 5); parent.add_child(row); var label := Label.new(); label.text = "%s %d" % [label_text, int(round(value))]; label.custom_minimum_size = Vector2(45, 0); label.add_theme_font_size_override("font_size", 10); label.add_theme_color_override("font_color", V17_MUTED); row.add_child(label); var bar := ProgressBar.new(); bar.min_value = 0; bar.max_value = 100; bar.value = clamp(value, 0, 100); bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 8); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.09, 0.13, 0.18, 1.0); bg.set_corner_radius_all(5); var fill := StyleBoxFlat.new(); fill.bg_color = fill_color; fill.set_corner_radius_all(5); bar.add_theme_stylebox_override("background", bg); bar.add_theme_stylebox_override("fill", fill); row.add_child(bar)
func _v17_fight_action(parent: GridContainer, action_id: String, selected_plan: Dictionary) -> void:
    var action: Dictionary = combat.balance.actions[action_id]; var recommended := bool(selected_plan.get("action_modifiers", {}).has(action_id)); var button := Button.new(); var stamina := int(action.get("stamina", 0)); var stamina_text := "STA +%d" % abs(stamina) if stamina < 0 else "STA %d" % stamina; button.text = "%s\n%s%s" % [_action_label(action_id), "★ PLAN\n" if recommended else "", stamina_text]; button.custom_minimum_size = Vector2(0, 66); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.mouse_filter = Control.MOUSE_FILTER_PASS; button.add_theme_font_size_override("font_size", 13); button.add_theme_color_override("font_color", V17_GOLD if recommended else V17_TEXT); button.add_theme_stylebox_override("normal", _v17_box_style(Color(0.035, 0.060, 0.088, 1.0), V17_GOLD if recommended else V17_BORDER, 11, 8)); button.add_theme_stylebox_override("pressed", _v17_box_style(Color(0.10, 0.075, 0.035, 1.0), V17_GOLD, 11, 8)); button.pressed.connect(Callable(self, "_choose_fight_action").bind(action_id)); parent.add_child(button)
func _v17_recommendation(action_id: String) -> String:
    match action_id:
        "guard": return "바디로 체력을 깎아보세요"
        "power": return "가드 또는 카운터를 준비하세요"
        "jab": return "카운터 타이밍을 노려보세요"
        "body": return "거리 유지 후 잽으로 끊으세요"
        "counter": return "잽으로 안전하게 선점하세요"
        _: return "상대 움직임을 먼저 읽으세요"
func _v17_section_heading(title_text: String, subtitle: String) -> void:
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); body.add_child(row); var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(left); _v17_title(left, title_text, 27); _v17_copy(left, subtitle, true); var mark := Label.new(); mark.text = "—"; mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; mark.add_theme_font_size_override("font_size", 24); mark.add_theme_color_override("font_color", V17_GOLD); row.add_child(mark)
func _v17_panel(parent: Container, highlighted: bool) -> VBoxContainer:
    var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel", _v17_box_style(V17_PANEL_2 if highlighted else V17_PANEL, V17_GOLD if highlighted else V17_BORDER, 14, 10)); parent.add_child(panel); var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 6); panel.add_child(box); return box
func _v17_grid(columns: int) -> GridContainer:
    var grid := GridContainer.new(); grid.columns = columns; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); body.add_child(grid); return grid
func _v17_title(parent: Container, text_value: String, size: int) -> Label:
    var label := Label.new(); label.text = text_value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", V17_TEXT); parent.add_child(label); return label
func _v17_eyebrow(parent: Container, text_value: String) -> Label:
    var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size", 11); label.add_theme_color_override("font_color", V17_GOLD); parent.add_child(label); return label
func _v17_copy(parent: Container, text_value: String, muted: bool) -> Label:
    var label := Label.new(); label.text = text_value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.add_theme_font_size_override("font_size", 12); label.add_theme_color_override("font_color", V17_MUTED if muted else V17_TEXT); parent.add_child(label); return label
func _v17_chip(parent: Container, text_value: String, color: Color) -> Label:
    var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_theme_stylebox_override("panel", _v17_box_style(Color(0.035, 0.065, 0.093, 1.0), Color(color.r, color.g, color.b, 0.55), 7, 4)); parent.add_child(panel); var label := Label.new(); label.text = text_value; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 10); label.add_theme_color_override("font_color", color); panel.add_child(label); return label
func _v17_gold_button(text_value: String) -> Button:
    var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(0, 52); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.mouse_filter = Control.MOUSE_FILTER_PASS; button.add_theme_font_size_override("font_size", 14); button.add_theme_color_override("font_color", Color(0.07, 0.055, 0.025, 1.0)); button.add_theme_stylebox_override("normal", _v17_box_style(V17_GOLD, Color(1.0, 0.82, 0.43, 1.0), 9, 8)); button.add_theme_stylebox_override("pressed", _v17_box_style(Color(0.72, 0.49, 0.18, 1.0), V17_GOLD, 9, 8)); return button
func _v17_dark_button(text_value: String) -> Button:
    var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(0, 52); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.mouse_filter = Control.MOUSE_FILTER_PASS; button.add_theme_font_size_override("font_size", 13); button.add_theme_color_override("font_color", V17_TEXT); button.add_theme_stylebox_override("normal", _v17_box_style(Color(0.035, 0.060, 0.088, 1.0), V17_BORDER, 9, 8)); button.add_theme_stylebox_override("pressed", _v17_box_style(Color(0.065, 0.090, 0.12, 1.0), V17_GOLD_SOFT, 9, 8)); return button
func _v17_secondary_button(text_value: String) -> Button:
    var button := _v17_dark_button(text_value); button.custom_minimum_size.y = 56; button.add_theme_color_override("font_color", V17_MUTED); return button
func _v17_box_style(bg: Color, border: Color, radius: int, margin_value: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = bg; style.border_color = border; style.set_border_width_all(1); style.set_corner_radius_all(radius); style.content_margin_left = margin_value; style.content_margin_right = margin_value; style.content_margin_top = margin_value; style.content_margin_bottom = margin_value; style.shadow_color = Color(0, 0, 0, 0.24); style.shadow_size = 3; return style
func _v17_circle_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style := _v17_box_style(bg, border, 14, 2); style.set_border_width_all(1); return style
func _v17_nav_style(selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = Color(0.08, 0.065, 0.035, 0.42) if selected else Color(0, 0, 0, 0); style.border_color = V17_GOLD if selected else Color(0, 0, 0, 0); style.border_width_top = 2 if selected else 0; style.content_margin_top = 5; style.content_margin_bottom = 5; return style
func _v17_training_name(action: Dictionary) -> String:
    match str(action.get("id", "")):
        "heavy_bag": return "샌드백 파워"
        "mitts": return "미트 집중"
        "roadwork": return "로드워크"
        "defense_drill": return "디펜스 드릴"
        "full_rest": return "완전 휴식"
        "rehab": return "재활 치료"
        "weight_cut": return "체중 감량 캠프"
        "sparring": return "강한 스파링"
        _: return str(action.get("name", "캠프"))
func _v17_training_description(action_id: String) -> String:
    match action_id:
        "mitts": return "정확한 타이밍과 콤비네이션을 연습합니다."
        "roadwork": return "지구력과 심폐 능력을 강화합니다."
        "heavy_bag": return "강한 펀치와 파워를 집중적으로 훈련합니다."
        "defense_drill": return "방어 기술과 링에서의 생존력을 높입니다."
        "sparring": return "실전처럼 강도 높은 훈련으로 경기력을 점검합니다."
        "full_rest": return "몸과 마음을 회복하고 컨디션을 끌어올립니다."
        "rehab": return "부상을 관리하고 회복에 집중합니다."
        "weight_cut": return "체급에 맞춰 체중을 정리합니다."
        _: return "이번 캠프의 목표에 집중합니다."
func _v17_training_pose(action_id: String) -> String:
    match action_id:
        "mitts": return "jab"
        "roadwork": return "idle"
        "heavy_bag", "sparring": return "power"
        "defense_drill": return "guard"
        "full_rest", "rehab": return "idle"
        "weight_cut": return "body"
        _: return "idle"
func _v17_training_symbol(action_id: String) -> String:
    match action_id:
        "mitts": return "◎"
        "roadwork": return "↗"
        "heavy_bag", "sparring": return "◆"
        "defense_drill": return "⬡"
        "full_rest": return "▰"
        "rehab": return "+"
        "weight_cut": return "◇"
        _: return "●"
func _v17_opponent_name(opponent: Dictionary) -> String:
    return str(opponent.get("name", "OPPONENT"))
func _v17_country(opponent: Dictionary) -> String:
    return VisualAssetCatalog.opponent_country_badge(str(opponent.get("name", "")))
func _v17_visual_profile(opponent: Dictionary) -> String:
    return VisualAssetCatalog.opponent_visual_profile_for_name(str(opponent.get("name", "")))
func _v17_visual_style(opponent: Dictionary) -> String:
    match _v17_visual_profile(opponent):
        "black": return "swarmer"
        "latino": return "outboxer"
        "european": return "counter"
        _: return "slugger"
func _v17_opponent_texture(opponent: Dictionary) -> Texture2D:
    match _v17_visual_profile(opponent):
        "black": return VisualAssetCatalog.portrait_texture(false, "swarmer")
        "latino": return VisualAssetCatalog.portrait_texture(false, "outboxer")
        "european": return VisualAssetCatalog.portrait_texture(false, "counter")
        _:
            var fighter := VisualAssetCatalog.fighter_texture(false, "slugger", "idle"); return fighter if fighter != null else VisualAssetCatalog.portrait_texture(true)
func _v17_flag(country: String) -> String:
    match country:
        "KR": return "[KR]"
        "US": return "[US]"
        "MX": return "[MX]"
        "JP": return "[JP]"
        "RU": return "[RU]"
        "BR": return "[BR]"
        _: return ""
func _v17_opponent_quote(opponent: Dictionary) -> String:
    match str(opponent.get("id", "")):
        "han_do-yun": return "“끝까지 들어온다. 쓰러질 때까지.”"
        "seo_min-jae": return "“맞히지 못하면, 이길 수도 없다.”"
        "park_tae-ho": return "“한 방이면 끝이다.”"
        _: return "“링 위에서 답을 보여주겠다.”"
func _v17_summary_opponent_name(summary: Dictionary) -> String:
    return str(summary.get("opponent_name", "OPPONENT"))
func _v17_money(value: int) -> String:
    var s := str(abs(value)); var out := "";
    while s.length() > 3: out = "," + s.right(3) + out; s = s.left(s.length() - 3)
    out = s + out; return ("-" if value < 0 else "") + out
