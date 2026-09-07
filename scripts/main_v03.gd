extends "res://scripts/main.gd"

const STAT_LABELS := {"power":"P", "speed":"S", "technique":"T", "defense":"D", "conditioning":"C"}

func _render_phase() -> void:
    if str(GameState.state.phase) == "game_plan":
        _clear_body()
        _render_status()
        _render_game_plan()
        return
    super._render_phase()

func _render_status() -> void:
    super._render_status()
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var identity_name := str(boxer.get("identity_name", "균형형"))
    var signature := str(boxer.get("identity_signature", ""))
    var plan_text := ""
    if str(GameState.state.get("phase", "")) in ["game_plan", "fight"]:
        var plan: Dictionary = GameState.get_selected_game_plan()
        if not plan.is_empty() and not str(GameState.state.get("selected_game_plan", "")).is_empty():
            plan_text = " · 게임플랜 [%s]" % str(plan.name)
    status.text += "\n복싱 정체성 [%s]%s%s" % [identity_name, (" · " + signature if not signature.is_empty() else ""), plan_text]

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

    var identity_note := Label.new()
    identity_note.text = "내 복서: %s — %s" % [str(GameState.state.boxer.get("identity_name", "균형형")), GameState.identity_description()]
    identity_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(identity_note)

    _section("게임 플랜", "이 선택은 이번 경기에서만 적용됩니다. 추천은 정답이 아니라 상대 성향을 읽기 위한 힌트입니다.")
    var suggested: Array = scouting.get("suggested_plans", [])
    for plan in GameState.game_plans:
        var recommended := str(plan.id) in suggested
        var mark := "★ 추천 · " if recommended else ""
        var label := "%s%s  [리스크 %s]\n%s\n%s" % [
            mark, str(plan.name), str(plan.get("risk", "중간")), str(plan.description), _plan_effect_text(plan)
        ]
        _button(label, Callable(self, "_choose_game_plan").bind(str(plan.id)))

func _choose_game_plan(plan_id: String) -> void:
    var result := GameState.select_game_plan(plan_id)
    if bool(result.get("ok", false)):
        _render_phase()

func _start_fight() -> void:
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.selected_opponent))
    if current_opponent.is_empty():
        GameState.state.phase = "fight_offer"
        SaveService.save_game(GameState.state)
        _render_phase()
        return

    combat = CombatEngineV03.new(int(GameState.state.get("fight_seed", 1)))
    var fight_boxer := GameState.get_fight_boxer()
    var saved_fight: Dictionary = GameState.state.get("active_fight", {})
    if saved_fight.is_empty():
        combat.start(fight_boxer, current_opponent)
        GameState.save_active_fight(combat.export_state())
    else:
        combat.restore(fight_boxer, current_opponent, saved_fight)
    _render_fight()

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
        if not values.is_empty():
            chunks.append("%s %s" % [_action_label(action_id), " ".join(values)])
    return "효과 없음" if chunks.is_empty() else " · ".join(chunks)

func _tendency_text(tendencies: Dictionary) -> String:
    var chunks: Array[String] = []
    for action_id in ["jab", "body", "power", "guard", "counter"]:
        var probability := float(tendencies.get(action_id, 0.0))
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
