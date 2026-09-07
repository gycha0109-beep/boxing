class_name CombatPresentation
extends RefCounted

const ACTION_LABELS := {
    "jab": "잽",
    "power": "강타",
    "body": "바디",
    "guard": "가드",
    "counter": "카운터"
}

static func telegraph_title(telegraph: Dictionary) -> String:
    return str(telegraph.get("title", "상대 움직임 관찰 중"))

static func telegraph_copy(telegraph: Dictionary) -> String:
    var copy: String = str(telegraph.get("copy", "아직 확실한 신호가 없습니다."))
    var cue: String = str(telegraph.get("cue", ""))
    var confidence: int = int(telegraph.get("confidence", 0))
    var parts: Array[String] = [copy]
    if not cue.is_empty():
        parts.append(cue)
    if confidence > 0:
        parts.append("READ %d%%" % confidence)
    return "\n".join(parts)

static func exchange_headline(exchange: Dictionary) -> String:
    if exchange.is_empty():
        return ""
    if bool(exchange.get("read_failed", false)):
        return "READ FAILED"
    if bool(exchange.get("counter_success", false)):
        return "COUNTER!"
    var player_event: Dictionary = exchange.get("player_event", {})
    var opponent_event: Dictionary = exchange.get("opponent_event", {})
    if bool(player_event.get("knockout", false)):
        return "KNOCKDOWN!"
    if bool(opponent_event.get("knockout", false)):
        return "DOWN!"
    if str(player_event.get("action", "")) == "body" and bool(player_event.get("hit", false)):
        return "BODY HIT"
    if bool(player_event.get("hit", false)):
        return "%s 적중" % action_label(str(player_event.get("action", "")))
    if bool(player_event.get("miss", false)):
        return "%s 빗나감" % action_label(str(player_event.get("action", "")))
    if bool(player_event.get("guard", false)):
        return "가드 유지"
    return "교환 종료"

static func exchange_detail(exchange: Dictionary, opponent_name: String) -> String:
    if exchange.is_empty():
        return ""
    var lines: Array[String] = []
    var player_action: String = action_label(str(exchange.get("player_action", "")))
    var opponent_action: String = action_label(str(exchange.get("opponent_action", "")))
    var first_actor: String = str(exchange.get("first_actor", "player"))
    if first_actor == "player":
        lines.append("나 %s → %s %s" % [player_action, opponent_name, opponent_action])
    else:
        lines.append("%s %s → 나 %s" % [opponent_name, opponent_action, player_action])

    var player_event: Dictionary = exchange.get("player_event", {})
    var opponent_event: Dictionary = exchange.get("opponent_event", {})
    if bool(player_event.get("hit", false)):
        lines.append("상대 HP -%d" % int(round(float(player_event.get("damage", 0.0)))))
    if float(player_event.get("target_stamina_damage", 0.0)) > 0.0:
        lines.append("상대 STA -%d" % int(round(float(player_event.get("target_stamina_damage", 0.0)))))
    if bool(opponent_event.get("hit", false)):
        lines.append("내 HP -%d" % int(round(float(opponent_event.get("damage", 0.0)))))
    if float(opponent_event.get("target_stamina_damage", 0.0)) > 0.0:
        lines.append("내 STA -%d" % int(round(float(opponent_event.get("target_stamina_damage", 0.0)))))

    if bool(exchange.get("read_success", false)):
        lines.append("큰 공격을 읽었습니다. Counter Trap 조건 충족.")
    elif bool(exchange.get("read_failed", false)):
        lines.append("큰 공격을 기다렸지만 상대가 다른 선택을 했습니다. Counter Trap 페널티 적용.")

    var opponent_body_state: String = body_state_label(str(exchange.get("opponent_body_state", "stable")))
    if opponent_body_state != "안정":
        lines.append("상대 몸통 상태: %s" % opponent_body_state)
    return "\n".join(lines)

static func round_summary(exchange: Dictionary, player_name: String, opponent_name: String) -> String:
    if not bool(exchange.get("round_ended", false)):
        return ""
    var card: Array = exchange.get("round_card", [])
    var score_text: String = ""
    if card.size() >= 2:
        score_text = "%s %d : %d %s" % [player_name, int(card[0]), int(card[1]), opponent_name]
    var completed_round: int = int(exchange.get("completed_round", 0))
    var lines: Array[String] = ["ROUND %d 종료" % completed_round]
    if not score_text.is_empty():
        lines.append("예상 점수 · " + score_text)
    lines.append(corner_advice(exchange))
    return "\n".join(lines)

static func corner_advice(exchange: Dictionary) -> String:
    if bool(exchange.get("read_failed", false)):
        return "코너: 상대가 큰 공격만 던지는 건 아닙니다. 카운터를 남발하지 마세요."
    var body_state: String = str(exchange.get("opponent_body_state", "stable"))
    if body_state in ["hurt", "critical"]:
        return "코너: 몸통이 먹히고 있습니다. 후반 스태미나를 계속 압박하세요."
    var player_hp_delta: float = float(exchange.get("player_hp_delta", 0.0))
    var opponent_hp_delta: float = float(exchange.get("opponent_hp_delta", 0.0))
    if abs(opponent_hp_delta) > abs(player_hp_delta) + 3.0:
        return "코너: 지금 교환은 이겼습니다. 같은 리듬을 유지하세요."
    if abs(player_hp_delta) > abs(opponent_hp_delta) + 3.0:
        return "코너: 정면 교환 손해가 큽니다. 다음 선택은 안전하게 가져가세요."
    return "코너: 큰 차이는 없습니다. 상대 텔을 한 번 더 확인하세요."

static func action_button_text(action_id: String, action: Dictionary, plan: Dictionary) -> String:
    var label: String = action_label(action_id)
    var stamina: int = int(action.get("stamina", 0))
    var cost_text: String = "STA +%d" % abs(stamina) if stamina < 0 else "STA %d" % stamina
    var plan_mark: String = ""
    var action_modifiers: Dictionary = plan.get("action_modifiers", {})
    if action_modifiers.has(action_id):
        plan_mark = " · ★ PLAN"
    return "%s%s\n%s" % [label, plan_mark, cost_text]

static func body_state_label(state_id: String) -> String:
    match state_id:
        "strained": return "호흡 흔들림"
        "hurt": return "몸통 데미지 누적"
        "critical": return "탈진 직전"
        _: return "안정"

static func action_label(action_id: String) -> String:
    return str(ACTION_LABELS.get(action_id, action_id))
