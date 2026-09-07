extends Control

const STAT_LABELS := {"power":"P", "speed":"S", "technique":"T", "defense":"D", "conditioning":"C"}
const ACTION_IDS := ["jab", "power", "body", "guard", "counter"]
const PANEL_BG := Color(0.09, 0.10, 0.13, 1.0)
const PANEL_BORDER := Color(0.19, 0.21, 0.26, 1.0)
const MUTED_TEXT := Color(0.68, 0.70, 0.75, 1.0)
const ACCENT_TEXT := Color(0.92, 0.70, 0.34, 1.0)
const DANGER_TEXT := Color(0.95, 0.38, 0.34, 1.0)
const HP_FILL := Color(0.78, 0.25, 0.25, 1.0)
const STA_FILL := Color(0.26, 0.58, 0.82, 1.0)

var camp_actions: Array = []
var opponents: Array = []
var combat: CombatEngine
var current_opponent: Dictionary = {}

var header: Label
var body: VBoxContainer
var status: Label

func _ready() -> void:
    camp_actions = _load_array("res://data/camp_actions.json")
    opponents = _load_array("res://data/opponents.json")
    _build_shell()
    _render_phase()

func _build_shell() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 22)
    margin.add_theme_constant_override("margin_bottom", 20)
    add_child(margin)

    var root: VBoxContainer = VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    margin.add_child(root)

    header = Label.new()
    header.text = "TWELVE COUNT"
    header.add_theme_font_size_override("font_size", 28)
    header.add_theme_color_override("font_color", ACCENT_TEXT)
    root.add_child(header)

    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 14)
    status.add_theme_color_override("font_color", MUTED_TEXT)
    root.add_child(status)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 12)
    scroll.add_child(body)

func _render_phase() -> void:
    _clear_body()
    _render_status()
    match str(GameState.state.phase):
        "camp": _render_camp()
        "fight_offer": _render_offers()
        "game_plan": _render_game_plan()
        "fight": _start_fight()
        "result": _render_result()
        "event": _render_event()
        "career_summary": _render_career_summary()
        _: _render_camp()

func _render_status() -> void:
    var s: Dictionary = GameState.state
    var b: Dictionary = s.boxer
    var c: Dictionary = s.career
    var identity_name: String = str(b.get("identity_name", "균형형"))
    if str(s.phase) == "fight":
        var plan: Dictionary = GameState.get_selected_game_plan()
        status.text = "%s · %s · %s #%d\n%d전 %d승 %d패 %d무 · %s · 게임플랜 [%s]" % [
            b.name, GameState.age_text(), GameState.tier_label(), int(c.rank),
            c.fights, c.wins, c.losses, c.draws, identity_name, str(plan.get("name", "균형 운영"))
        ]
        return

    var injury_text: String = "없음"
    if not b.injury.is_empty():
        injury_text = "%s(%d캠프)" % [b.injury.name, int(b.injury.remaining_camps)]
    var signature: String = str(b.get("identity_signature", ""))
    status.text = "%s · %s · %s · 특성 [%s]\n복싱 정체성 [%s]%s\n%d전 %d승 %d패 %d무 · 커리어 %dpt · 랭킹 #%d\nP%d S%d T%d D%d C%d · 피로 %d%% · 건강 %d%%\n체중 %.2fkg / 한계 %.1fkg · 부상 %s · 보유금 %d원" % [
        b.name, GameState.age_text(), GameState.tier_label(), b.trait_name,
        identity_name, (" · " + signature if not signature.is_empty() else ""),
        c.fights, c.wins, c.losses, c.draws, c.career_points, c.rank,
        b.power, b.speed, b.technique, b.defense, b.conditioning, b.fatigue, b.health,
        float(b.weight_kg), float(GameState.career_balance.weight_class.limit_kg), injury_text, c.money
    ]

func _section(title: String, copy: String) -> void:
    var t: Label = Label.new()
    t.text = title
    t.add_theme_font_size_override("font_size", 24)
    body.add_child(t)
    var p: Label = Label.new()
    p.text = copy
    p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    p.add_theme_color_override("font_color", MUTED_TEXT)
    body.add_child(p)

func _button(text: String, callable: Callable, disabled: bool = false) -> void:
    var btn: Button = Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 64)
    btn.disabled = disabled
    btn.pressed.connect(callable)
    body.add_child(btn)

func _card_box(title: String, copy: String = "") -> VBoxContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG
    style.border_color = PANEL_BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    panel.add_theme_stylebox_override("panel", style)
    body.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)
    if not title.is_empty():
        var title_label := Label.new()
        title_label.text = title
        title_label.add_theme_font_size_override("font_size", 18)
        box.add_child(title_label)
    if not copy.is_empty():
        var copy_label := Label.new()
        copy_label.text = copy
        copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        copy_label.add_theme_color_override("font_color", MUTED_TEXT)
        box.add_child(copy_label)
    return box

func _meter(parent: VBoxContainer, label_text: String, value: float, fill_color: Color) -> void:
    var label := Label.new()
    label.text = "%s  %d" % [label_text, int(round(value))]
    label.add_theme_font_size_override("font_size", 13)
    parent.add_child(label)

    var progress := ProgressBar.new()
    progress.min_value = 0.0
    progress.max_value = 100.0
    progress.value = clamp(value, 0.0, 100.0)
    progress.show_percentage = false
    progress.custom_minimum_size = Vector2(0, 12)
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.16, 0.17, 0.20, 1.0)
    background.set_corner_radius_all(6)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(6)
    progress.add_theme_stylebox_override("background", background)
    progress.add_theme_stylebox_override("fill", fill)
    parent.add_child(progress)

func _render_camp() -> void:
    var injury_note: String = ""
    if not GameState.state.boxer.injury.is_empty():
        injury_note = "\n현재 부상: %s. 재활을 고르면 기간을 줄일 수 있습니다." % GameState.state.boxer.injury.name
    _section("이번 캠프", "한 번의 선택만 할 수 있습니다. 성장, 회복, 체중 중 무엇을 포기할지 결정합니다.%s" % injury_note)
    for action in camp_actions:
        var details: Array[String] = []
        for key in action.effects.keys():
            details.append("%s %s" % [str(key), _signed_value(action.effects[key])])
        var affordable: bool = int(GameState.state.career.money) >= int(action.cost)
        var label: String = "%s · %d원\n%s · 부상위험 %.1f%%" % [action.name, int(action.cost), ", ".join(details), float(action.risk) * 100.0]
        if not affordable:
            label += "\n자금 부족"
        _button(label, Callable(self, "_choose_camp_action").bind(action), not affordable)

func _choose_camp_action(action: Dictionary) -> void:
    var action_result: Dictionary = GameState.apply_camp_action(action)
    if bool(action_result.get("ok", false)):
        _render_phase()

func _render_offers() -> void:
    var offers: Array = GameState.get_fight_offers(opponents)
    _section("경기 계약", "현재 커리어 위치에 맞는 계약입니다. 상대를 고른 뒤 바로 싸우지 않고 스카우팅 리포트를 보고 이번 경기의 게임플랜을 결정합니다.")
    for opponent in offers:
        var st: Dictionary = opponent.stats
        var title_mark: String = " · TITLE" if bool(opponent.get("title_fight", false)) else ""
        var label: String = "%s  #%d  [%s/%s]%s\nP%d S%d T%d D%d C%d\n파이트머니 %d원 · 승리 +%dpt · 패배 -%dpt" % [
            opponent.name, opponent.rank, opponent.tier, opponent.style, title_mark,
            st.power, st.speed, st.technique, st.defense, st.conditioning,
            opponent.purse, opponent.career_points_win, opponent.career_points_loss
        ]
        _button(label, Callable(self, "_choose_opponent").bind(opponent))

func _choose_opponent(opponent: Dictionary) -> void:
    current_opponent = opponent
    GameState.select_opponent(opponent)
    _render_phase()

func _render_game_plan() -> void:
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.selected_opponent))
    if current_opponent.is_empty():
        GameState.state.phase = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return

    var scouting: Dictionary = current_opponent.get("scouting", {})
    var tendencies: Dictionary = current_opponent.get("tendencies", {})
    _section("상대 스카우팅 · %s" % current_opponent.name,
        "스타일: %s · 랭킹 #%d\n강점: %s\n약점: %s\n텔: %s\n\n행동 경향: %s" % [
            str(current_opponent.style), int(current_opponent.rank),
            str(scouting.get("strength", "정보 부족")),
            str(scouting.get("weakness", "정보 부족")),
            str(scouting.get("tell", "정보 부족")),
            _tendency_text(tendencies)
        ])

    var identity_note: Label = Label.new()
    identity_note.text = "내 복서: %s — %s" % [str(GameState.state.boxer.get("identity_name", "균형형")), GameState.identity_description()]
    identity_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(identity_note)

    _section("게임 플랜", "이번 경기에서만 적용됩니다. ★는 스카우팅 추천이지만 정답은 아닙니다. 상대의 습관과 내 복서의 정체성을 함께 보고 선택합니다.")
    var suggested: Array = scouting.get("suggested_plans", [])
    for plan in GameState.game_plans:
        var recommended: bool = str(plan.id) in suggested
        var mark: String = "★ 추천 · " if recommended else ""
        var label: String = "%s%s  [리스크 %s]\n%s\n%s" % [
            mark, str(plan.name), str(plan.get("risk", "중간")), str(plan.description), _plan_effect_text(plan)
        ]
        _button(label, Callable(self, "_choose_game_plan").bind(str(plan.id)))

func _choose_game_plan(plan_id: String) -> void:
    var plan_result: Dictionary = GameState.select_game_plan(plan_id)
    if bool(plan_result.get("ok", false)):
        _render_phase()

func _start_fight() -> void:
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.selected_opponent))
    if current_opponent.is_empty():
        GameState.state.phase = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return

    combat = CombatEngine.new(int(GameState.state.get("fight_seed", 1)))
    var fight_boxer: Dictionary = GameState.get_fight_boxer()
    var saved_fight: Dictionary = GameState.state.get("active_fight", {})
    if saved_fight.is_empty():
        combat.start(fight_boxer, current_opponent)
        GameState.save_active_fight(combat.export_state())
    else:
        combat.restore(fight_boxer, current_opponent, saved_fight)
    _render_fight()

func _render_fight() -> void:
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
    fight_subtitle.add_theme_color_override("font_color", MUTED_TEXT)
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
    versus.add_theme_color_override("font_color", ACCENT_TEXT)
    names.add_child(versus)
    var opponent_name := Label.new()
    opponent_name.text = str(current_opponent.name)
    opponent_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    opponent_name.add_theme_font_size_override("font_size", 17)
    names.add_child(opponent_name)

    var gauge_grid := GridContainer.new()
    gauge_grid.columns = 2
    gauge_grid.add_theme_constant_override("h_separation", 16)
    ring_box.add_child(gauge_grid)
    var player_gauges := VBoxContainer.new()
    player_gauges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gauge_grid.add_child(player_gauges)
    _meter(player_gauges, "HP", float(snap.player_hp), HP_FILL)
    _meter(player_gauges, "STA", float(snap.player_stamina), STA_FILL)
    var opponent_gauges := VBoxContainer.new()
    opponent_gauges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gauge_grid.add_child(opponent_gauges)
    _meter(opponent_gauges, "HP", float(snap.opponent_hp), HP_FILL)
    _meter(opponent_gauges, "STA", float(snap.opponent_stamina), STA_FILL)

    var weigh_in: Dictionary = GameState.state.last_weigh_in
    var weigh_text: String = "계체 통과"
    if str(weigh_in.get("status", "pass")) == "emergency_cut":
        weigh_text = "긴급 감량 성공 · 피로/건강 페널티"
    elif str(weigh_in.get("status", "pass")) == "miss":
        weigh_text = "계체 실패 · 파이트머니 삭감"
    var weigh_label := Label.new()
    weigh_label.text = weigh_text
    weigh_label.add_theme_font_size_override("font_size", 12)
    weigh_label.add_theme_color_override("font_color", MUTED_TEXT)
    ring_box.add_child(weigh_label)

    var last_exchange: Dictionary = snap.get("last_exchange", {})
    if not last_exchange.is_empty():
        var headline: String = CombatPresentation.exchange_headline(last_exchange)
        var feedback_box: VBoxContainer = _card_box(headline, CombatPresentation.exchange_detail(last_exchange, str(current_opponent.name)))
        if bool(last_exchange.get("read_failed", false)):
            var warning := Label.new()
            warning.text = "카운터 읽기 실패"
            warning.add_theme_color_override("font_color", DANGER_TEXT)
            feedback_box.add_child(warning)
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
    read_title.add_theme_color_override("font_color", ACCENT_TEXT)
    read_box.add_child(read_title)
    var read_copy := Label.new()
    read_copy.text = CombatPresentation.telegraph_copy(telegraph)
    read_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    read_box.add_child(read_copy)

    var body_state: String = CombatPresentation.body_state_label(str(last_exchange.get("opponent_body_state", "stable"))) if not last_exchange.is_empty() else "안정"
    var tactical_note := Label.new()
    tactical_note.text = "상대 몸통 상태: %s · 상대 스타일: %s" % [body_state, str(current_opponent.style)]
    tactical_note.add_theme_color_override("font_color", MUTED_TEXT)
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
    for action_id in ACTION_IDS:
        var action: Dictionary = combat.balance.actions[action_id]
        var btn := Button.new()
        btn.text = CombatPresentation.action_button_text(action_id, action, selected_plan)
        btn.custom_minimum_size = Vector2(0, 76)
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.add_theme_font_size_override("font_size", 16)
        if selected_plan.get("action_modifiers", {}).has(action_id):
            btn.add_theme_color_override("font_color", ACCENT_TEXT)
        btn.pressed.connect(Callable(self, "_choose_fight_action").bind(action_id))
        action_grid.add_child(btn)

func _choose_fight_action(action: String) -> void:
    combat.resolve_exchange(action)
    GameState.save_active_fight(combat.export_state())
    _render_fight()

func _render_result() -> void:
    var summary: Dictionary = GameState.state.last_fight_summary
    var result_label: String = _result_label(str(summary.get("result", GameState.state.last_result)))
    var weigh_in: Dictionary = summary.get("weigh_in", {})
    var weigh_copy: String = "계체 통과"
    if str(weigh_in.get("status", "pass")) == "emergency_cut":
        weigh_copy = "긴급 감량 후 출전"
    elif str(weigh_in.get("status", "pass")) == "miss":
        weigh_copy = "계체 실패로 수입 삭감"
    var plan: Dictionary = GameState.get_game_plan(str(summary.get("game_plan", "balanced")))
    _section("경기 종료 · %s" % result_label, "%s전 정산 완료. 게임플랜 [%s], 수입 %d원. %s. 커리어 포인트와 건강/피로/부상 상태가 저장되었습니다." % [summary.get("opponent_name", "상대"), str(plan.get("name", "균형 운영")), int(summary.get("purse", 0)), weigh_copy])
    _button("다음으로", func():
        GameState.advance_after_result()
        current_opponent = {}
        _render_phase()
    )

func _render_event() -> void:
    var event: Dictionary = GameState.state.pending_event
    if event.is_empty():
        GameState.resolve_pending_event()
        _render_phase()
        return
    _section(str(event.name), str(event.text))
    var effects: Array[String] = []
    for key in event.effects.keys():
        effects.append("%s %s" % [str(key), _signed_value(event.effects[key])])
    var effect_label: String = "효과: " + ", ".join(effects)
    var l: Label = Label.new()
    l.text = effect_label
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(l)
    _button("계속", func():
        GameState.resolve_pending_event()
        _render_phase()
    )

func _render_career_summary() -> void:
    var c: Dictionary = GameState.state.career
    var b: Dictionary = GameState.state.boxer
    _section("커리어 종료", "%s\n\n%s · %s\n최종 전적 %d승 %d패 %d무 · %d전 · 최종 %dpt · 보유금 %d원" % [
        GameState.ending_text(), str(b.get("identity_name", "균형형")), str(b.get("identity_signature", "")),
        c.wins, c.losses, c.draws, c.fights, c.career_points, c.money
    ])
    _button("새 커리어", func():
        GameState.new_career("무명 복서")
        current_opponent = {}
        _render_phase()
    )

func _find_opponent(opponent_id: String) -> Dictionary:
    for opponent in opponents:
        if str(opponent.id) == opponent_id:
            return opponent
    return {}

func _plan_effect_text(plan: Dictionary) -> String:
    var chunks: Array[String] = []
    var global_stats: Dictionary = plan.get("global_stats", {})
    if not global_stats.is_empty():
        var stat_chunks: Array[String] = []
        for stat in ["power", "speed", "technique", "defense", "conditioning"]:
            if global_stats.has(stat):
                stat_chunks.append("%s%s" % [STAT_LABELS[stat], _signed_value(global_stats[stat])])
        if not stat_chunks.is_empty():
            chunks.append("전체 " + " ".join(stat_chunks))
    var action_modifiers: Dictionary = plan.get("action_modifiers", {})
    for action_id in ["jab", "body", "power", "guard", "counter"]:
        if not action_modifiers.has(action_id):
            continue
        var values: Array[String] = []
        var mods: Dictionary = action_modifiers[action_id]
        for stat in ["power", "speed", "technique", "defense", "conditioning"]:
            if mods.has(stat):
                values.append("%s%s" % [STAT_LABELS[stat], _signed_value(mods[stat])])
        var required: Array = mods.get("requires_target_actions", [])
        var condition: String = ""
        if not required.is_empty():
            var action_names: Array[String] = []
            for target_action in required:
                action_names.append(_action_label(str(target_action)))
            condition = "(%s 상대 시) " % "/".join(action_names)
        if not values.is_empty():
            chunks.append("%s%s %s" % [condition, _action_label(action_id), " ".join(values)])
    return "효과 없음" if chunks.is_empty() else " · ".join(chunks)

func _tendency_text(tendencies: Dictionary) -> String:
    var chunks: Array[String] = []
    for action_id in ["jab", "body", "power", "guard", "counter"]:
        var probability: float = float(tendencies.get(action_id, 0.0))
        if probability > 0.0:
            chunks.append("%s %d%%" % [_action_label(action_id), int(round(probability * 100.0))])
    return ", ".join(chunks)

func _action_label(action_id: String) -> String:
    match action_id:
        "jab": return "잽"
        "power": return "강타"
        "body": return "바디"
        "guard": return "가드"
        "counter": return "카운터"
        _: return action_id

func _result_label(result: String) -> String:
    match result:
        "WIN_KO": return "KO승"
        "WIN_DEC": return "판정승"
        "LOSS_KO": return "KO패"
        "LOSS_DEC": return "판정패"
        "DRAW": return "무승부"
        _: return result

func _signed_value(value: Variant) -> String:
    if typeof(value) == TYPE_FLOAT:
        return "%+.2f" % float(value)
    if typeof(value) == TYPE_INT:
        return "%+d" % int(value)
    return str(value)

func _clear_body() -> void:
    for child in body.get_children():
        child.queue_free()

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []
