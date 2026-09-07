extends "res://scripts/main.gd"

const V05_ACTION_IDS := ["jab", "power", "body", "guard", "counter"]
const V05_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const V05_ACCENT := Color(0.92, 0.70, 0.34, 1.0)
const V05_DANGER := Color(0.95, 0.38, 0.34, 1.0)
const V05_HP := Color(0.78, 0.25, 0.25, 1.0)
const V05_STA := Color(0.26, 0.58, 0.82, 1.0)

var impact_feedback: ImpactFeedback

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    _clear_body()
    _render_status()

    var had_pending_action: bool = not combat.pending_opponent_action.is_empty()
    var telegraph: Dictionary = combat.prepare_exchange()
    if not had_pending_action and not telegraph.is_empty():
        GameState.save_active_fight(combat.export_state())

    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    var exchange_in_round: int = (int(snap.exchange) % int(combat.balance.fight.exchanges_per_round)) + 1

    var fight_title := Label.new()
    fight_title.text = "ROUND %d · EXCHANGE %d/%d" % [int(snap.round), exchange_in_round, int(combat.balance.fight.exchanges_per_round)]
    fight_title.add_theme_font_size_override("font_size", 24)
    body.add_child(fight_title)

    var fight_subtitle := Label.new()
    fight_subtitle.text = "%s vs %s · %s" % [GameState.state.boxer.name, current_opponent.name, str(selected_plan.get("name", "균형 운영"))]
    fight_subtitle.add_theme_color_override("font_color", V05_MUTED)
    body.add_child(fight_subtitle)

    var ring_box: VBoxContainer = _card_box("RING")
    var names := HBoxContainer.new()
    names.add_theme_constant_override("separation", 12)
    ring_box.add_child(names)
    var player_name := Label.new()
    player_name.text = str(GameState.state.boxer.name)
    player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    player_name.add_theme_font_size_override("font_size", 17)
    names.add_child(player_name)
    var versus := Label.new()
    versus.text = "VS"
    versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    versus.add_theme_color_override("font_color", V05_ACCENT)
    names.add_child(versus)
    var opponent_name := Label.new()
    opponent_name.text = str(current_opponent.name)
    opponent_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    opponent_name.add_theme_font_size_override("font_size", 17)
    names.add_child(opponent_name)

    var stage := FightStage.new()
    stage.configure(str(GameState.state.boxer.name), str(current_opponent.name), snap, telegraph)
    ring_box.add_child(stage)
    if not animated_exchange.is_empty():
        stage.play_exchange(animated_exchange)

    var gauge_grid := GridContainer.new()
    gauge_grid.columns = 2
    gauge_grid.add_theme_constant_override("h_separation", 16)
    ring_box.add_child(gauge_grid)
    var player_gauges := VBoxContainer.new()
    player_gauges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gauge_grid.add_child(player_gauges)
    _meter(player_gauges, "HP", float(snap.player_hp), V05_HP)
    _meter(player_gauges, "STA", float(snap.player_stamina), V05_STA)
    var opponent_gauges := VBoxContainer.new()
    opponent_gauges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gauge_grid.add_child(opponent_gauges)
    _meter(opponent_gauges, "HP", float(snap.opponent_hp), V05_HP)
    _meter(opponent_gauges, "STA", float(snap.opponent_stamina), V05_STA)

    var weigh_in: Dictionary = GameState.state.last_weigh_in
    var weigh_text: String = "계체 통과"
    if str(weigh_in.get("status", "pass")) == "emergency_cut":
        weigh_text = "긴급 감량 성공 · 피로/건강 페널티"
    elif str(weigh_in.get("status", "pass")) == "miss":
        weigh_text = "계체 실패 · 파이트머니 삭감"
    var weigh_label := Label.new()
    weigh_label.text = weigh_text
    weigh_label.add_theme_font_size_override("font_size", 12)
    weigh_label.add_theme_color_override("font_color", V05_MUTED)
    ring_box.add_child(weigh_label)

    var last_exchange: Dictionary = snap.get("last_exchange", {})
    if not last_exchange.is_empty():
        var headline: String = CombatPresentation.exchange_headline(last_exchange)
        var feedback_box: VBoxContainer = _card_box(headline, CombatPresentation.exchange_detail(last_exchange, str(current_opponent.name)))
        if bool(last_exchange.get("read_failed", false)):
            var warning := Label.new()
            warning.text = "카운터 읽기 실패"
            warning.add_theme_color_override("font_color", V05_DANGER)
            feedback_box.add_child(warning)
        var profile_note := Label.new()
        profile_note.text = "IMPACT · %s" % ImpactFeedback.profile(last_exchange).to_upper()
        profile_note.add_theme_font_size_override("font_size", 11)
        profile_note.add_theme_color_override("font_color", V05_MUTED)
        feedback_box.add_child(profile_note)
        var round_copy: String = CombatPresentation.round_summary(last_exchange, str(GameState.state.boxer.name), str(current_opponent.name))
        if not round_copy.is_empty():
            _card_box("ROUND SUMMARY", round_copy)

    if bool(snap.finished):
        GameState.apply_fight_result(str(snap.result), current_opponent, snap)
        _button("경기 정산", func(): _render_phase())
        return

    var telegraph_title: String = "OPPONENT READ"
    if int(telegraph.get("confidence", 0)) > 0:
        telegraph_title += " · %d%%" % int(telegraph.get("confidence", 0))
    var read_box: VBoxContainer = _card_box(telegraph_title)
    var read_title := Label.new()
    read_title.text = CombatPresentation.telegraph_title(telegraph)
    read_title.add_theme_font_size_override("font_size", 20)
    read_title.add_theme_color_override("font_color", V05_ACCENT)
    read_box.add_child(read_title)
    var read_copy := Label.new()
    read_copy.text = CombatPresentation.telegraph_copy(telegraph)
    read_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    read_box.add_child(read_copy)

    var body_state: String = CombatPresentation.body_state_label(str(last_exchange.get("opponent_body_state", "stable"))) if not last_exchange.is_empty() else "안정"
    var tactical_note := Label.new()
    tactical_note.text = "상대 몸통 상태: %s · 상대 스타일: %s" % [body_state, _fight_style_label(str(current_opponent.style))]
    tactical_note.add_theme_color_override("font_color", V05_MUTED)
    body.add_child(tactical_note)

    var action_title := Label.new()
    action_title.text = "다음 행동"
    action_title.add_theme_font_size_override("font_size", 20)
    body.add_child(action_title)
    var action_grid := GridContainer.new()
    action_grid.columns = 2
    action_grid.add_theme_constant_override("h_separation", 8)
    action_grid.add_theme_constant_override("v_separation", 8)
    body.add_child(action_grid)
    for action_id in V05_ACTION_IDS:
        var action: Dictionary = combat.balance.actions[action_id]
        var btn := Button.new()
        btn.text = CombatPresentation.action_button_text(action_id, action, selected_plan)
        btn.custom_minimum_size = Vector2(0, 76)
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.add_theme_font_size_override("font_size", 16)
        if selected_plan.get("action_modifiers", {}).has(action_id):
            btn.add_theme_color_override("font_color", V05_ACCENT)
        btn.pressed.connect(Callable(self, "_choose_fight_action").bind(action_id))
        action_grid.add_child(btn)

func _choose_fight_action(action: String) -> void:
    var resolved: Dictionary = combat.resolve_exchange(action)
    var exchange: Dictionary = resolved.get("exchange_result", {})
    GameState.save_active_fight(combat.export_state())
    _impact().trigger(exchange)
    _render_fight(exchange)

func _impact() -> ImpactFeedback:
    if is_instance_valid(impact_feedback):
        return impact_feedback
    impact_feedback = ImpactFeedback.new()
    impact_feedback.name = "ImpactFeedback"
    add_child(impact_feedback)
    return impact_feedback

func _fight_style_label(style_id: String) -> String:
    match style_id:
        "swarmer": return "인파이터"
        "out_boxer": return "아웃복서"
        "slugger": return "슬러거"
        "counter", "counter_puncher": return "카운터 펀처"
        _: return style_id.replace("_", " ").capitalize()