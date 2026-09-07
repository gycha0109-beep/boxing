extends Control

const STAT_LABELS := {"power":"P", "speed":"S", "technique":"T", "defense":"D", "conditioning":"C"}

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
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 24)
    add_child(margin)

    var root: VBoxContainer = VBoxContainer.new()
    root.add_theme_constant_override("separation", 14)
    margin.add_child(root)

    header = Label.new()
    header.text = "TWELVE COUNT"
    header.add_theme_font_size_override("font_size", 30)
    root.add_child(header)

    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 15)
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
    var injury_text: String = "없음"
    if not b.injury.is_empty():
        injury_text = "%s(%d캠프)" % [b.injury.name, int(b.injury.remaining_camps)]
    var identity_name: String = str(b.get("identity_name", "균형형"))
    var signature: String = str(b.get("identity_signature", ""))
    var plan_text: String = ""
    if str(s.phase) == "fight" and not str(s.get("selected_game_plan", "")).is_empty():
        var plan: Dictionary = GameState.get_selected_game_plan()
        plan_text = " · 게임플랜 [%s]" % str(plan.get("name", "균형 운영"))
    status.text = "%s · %s · %s · 특성 [%s]\n복싱 정체성 [%s]%s%s\n%d전 %d승 %d패 %d무 · 커리어 %dpt · 랭킹 #%d\nP%d S%d T%d D%d C%d · 피로 %d%% · 건강 %d%%\n체중 %.2fkg / 한계 %.1fkg · 부상 %s · 보유금 %d원" % [
        b.name, GameState.age_text(), GameState.tier_label(), b.trait_name,
        identity_name, (" · " + signature if not signature.is_empty() else ""), plan_text,
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
    body.add_child(p)

func _button(text: String, callable: Callable, disabled: bool = false) -> void:
    var btn: Button = Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 64)
    btn.disabled = disabled
    btn.pressed.connect(callable)
    body.add_child(btn)

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
    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    _section("ROUND %d" % snap.round, "%s vs %s\n게임플랜: %s" % [GameState.state.boxer.name, current_opponent.name, str(selected_plan.get("name", "균형 운영"))])

    var weigh_in: Dictionary = GameState.state.last_weigh_in
    var weigh_text: String = "계체 통과"
    if str(weigh_in.get("status", "pass")) == "emergency_cut":
        weigh_text = "긴급 감량 성공 · 피로/건강 페널티"
    elif str(weigh_in.get("status", "pass")) == "miss":
        weigh_text = "계체 실패 · 파이트머니 삭감"

    var gauges: Label = Label.new()
    gauges.text = "%s\n나 HP %d / STA %d\n상대 HP %d / STA %d" % [weigh_text, int(snap.player_hp), int(snap.player_stamina), int(snap.opponent_hp), int(snap.opponent_stamina)]
    gauges.add_theme_font_size_override("font_size", 20)
    body.add_child(gauges)

    if not snap.last_log.is_empty():
        var log_label: Label = Label.new()
        log_label.text = "\n".join(snap.last_log)
        log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        body.add_child(log_label)

    if snap.finished:
        GameState.apply_fight_result(str(snap.result), current_opponent, snap)
        _button("경기 정산", func(): _render_phase())
        return

    var scouting: Dictionary = current_opponent.get("scouting", {})
    var hint: Label = Label.new()
    hint.text = "상대 텔: %s\n잽→카운터 견제 / 강타·바디→카운터 위험 / 가드→피해 감소. 게임플랜은 특정 행동의 효율을 바꾸지만 실제 교환 선택은 계속 플레이어가 합니다." % str(scouting.get("tell", current_opponent.style))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(hint)
    for action in ["jab", "power", "body", "guard", "counter"]:
        _button(str(combat.balance.actions[action].label), Callable(self, "_choose_fight_action").bind(action))

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
