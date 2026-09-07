class_name CombatEngine
extends RefCounted

const ACTION_ORDER := ["jab", "power", "body", "guard", "counter"]
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]
const COMMITTED_ATTACKS := ["power", "body"]

var rng := RandomNumberGenerator.new()
var balance: Dictionary = {}
var player: Dictionary = {}
var opponent: Dictionary = {}
var round_no: int = 1
var exchange_no: int = 0
var player_hp: float = 100.0
var opponent_hp: float = 100.0
var player_stamina: float = 100.0
var opponent_stamina: float = 100.0
var player_round_score: float = 0.0
var opponent_round_score: float = 0.0
var cards: Array = []
var finished: bool = false
var result: String = ""
var log: Array[String] = []
var pending_opponent_action: String = ""
var pending_telegraph: Dictionary = {}
var last_exchange: Dictionary = {}

func _init(seed_value: int = 1) -> void:
    rng.seed = seed_value
    balance = _load_json("res://data/balance.json")

func start(player_stats: Dictionary, opponent_data: Dictionary) -> void:
    player = player_stats.duplicate(true)
    opponent = opponent_data.duplicate(true)
    round_no = 1
    exchange_no = 0
    var player_health: float = float(player.get("health", 100))
    var player_fatigue: float = float(player.get("fatigue", 0))
    player_hp = clamp(75.0 + player_health * 0.25, 50.0, 100.0)
    opponent_hp = 100.0
    player_stamina = clamp(100.0 - player_fatigue * 0.55 - max(0.0, 100.0 - player_health) * 0.25, 42.0, 100.0)
    opponent_stamina = 100.0
    player_round_score = 0.0
    opponent_round_score = 0.0
    cards.clear()
    log.clear()
    finished = false
    result = ""
    pending_opponent_action = ""
    pending_telegraph = {}
    last_exchange = {}

func prepare_exchange() -> Dictionary:
    if finished:
        return {}
    if pending_opponent_action.is_empty():
        pending_opponent_action = _choose_opponent_action()
        pending_telegraph = _build_telegraph(pending_opponent_action)
    return pending_telegraph.duplicate(true)

func resolve_exchange(player_action: String) -> Dictionary:
    if finished:
        return snapshot()
    var telegraph: Dictionary = prepare_exchange()
    var opponent_action: String = pending_opponent_action
    pending_opponent_action = ""
    pending_telegraph = {}

    var round_before: int = round_no
    var player_hp_before: float = player_hp
    var opponent_hp_before: float = opponent_hp
    var player_stamina_before: float = player_stamina
    var opponent_stamina_before: float = opponent_stamina
    var cards_before: int = cards.size()

    exchange_no += 1
    player_round_score = 0.0 if exchange_no % int(balance.fight.exchanges_per_round) == 1 else player_round_score
    opponent_round_score = 0.0 if exchange_no % int(balance.fight.exchanges_per_round) == 1 else opponent_round_score

    var first_is_player: bool
    if player_action == "counter" and opponent_action in COMMITTED_ATTACKS:
        first_is_player = false
    elif opponent_action == "counter" and player_action in COMMITTED_ATTACKS:
        first_is_player = true
    else:
        var p_speed: float = float(player.speed) + rng.randf_range(-10.0, 10.0)
        var o_speed: float = float(opponent.stats.speed) + rng.randf_range(-10.0, 10.0)
        first_is_player = p_speed >= o_speed

    var events: Array = []
    var player_event: Dictionary = {}
    var opponent_event: Dictionary = {}
    if first_is_player:
        player_event = _perform(true, player_action, opponent_action, false)
        if not player_event.is_empty():
            events.append(player_event)
        if not finished:
            opponent_event = _perform(false, opponent_action, player_action, true)
            if not opponent_event.is_empty():
                events.append(opponent_event)
    else:
        opponent_event = _perform(false, opponent_action, player_action, false)
        if not opponent_event.is_empty():
            events.append(opponent_event)
        if not finished:
            player_event = _perform(true, player_action, opponent_action, true)
            if not player_event.is_empty():
                events.append(player_event)

    if not finished and exchange_no % int(balance.fight.exchanges_per_round) == 0:
        _score_round()
        if round_no >= int(balance.fight.rounds):
            _finish_decision()
        else:
            round_no += 1
            player_stamina = min(100.0, player_stamina + 9.0 + float(player.conditioning) * 0.05)
            opponent_stamina = min(100.0, opponent_stamina + 9.0 + float(opponent.stats.conditioning) * 0.05)

    var round_ended: bool = cards.size() > cards_before
    var round_card: Array = []
    if round_ended:
        round_card = cards[-1].duplicate()

    var plan_read: String = str(player_event.get("plan_read", "none"))
    var exchange_result: Dictionary = {
        "round": round_before,
        "completed_round": round_before if round_ended else 0,
        "exchange": exchange_no,
        "exchange_in_round": ((exchange_no - 1) % int(balance.fight.exchanges_per_round)) + 1,
        "player_action": player_action,
        "opponent_action": opponent_action,
        "first_actor": "player" if first_is_player else "opponent",
        "telegraph": telegraph.duplicate(true),
        "events": events.duplicate(true),
        "player_event": player_event.duplicate(true),
        "opponent_event": opponent_event.duplicate(true),
        "player_hp_delta": player_hp - player_hp_before,
        "opponent_hp_delta": opponent_hp - opponent_hp_before,
        "player_stamina_delta": player_stamina - player_stamina_before,
        "opponent_stamina_delta": opponent_stamina - opponent_stamina_before,
        "read_success": plan_read == "success",
        "read_failed": plan_read == "failed",
        "counter_success": plan_read == "success" and bool(player_event.get("hit", false)),
        "opponent_body_state": _body_state_id(opponent_stamina),
        "player_body_state": _body_state_id(player_stamina),
        "round_ended": round_ended,
        "round_card": round_card,
        "finished": finished,
        "result": result
    }
    last_exchange = exchange_result.duplicate(true)

    var out: Dictionary = snapshot()
    out["opponent_action"] = opponent_action
    out["exchange_result"] = exchange_result.duplicate(true)
    return out

func _perform(is_player: bool, action_id: String, target_action: String, reactive_window: bool) -> Dictionary:
    var actions: Dictionary = balance.actions
    if not actions.has(action_id):
        return {}
    var action: Dictionary = actions[action_id]
    var base_actor: Dictionary = player if is_player else opponent.stats
    var actor: Dictionary = _actor_for_action(base_actor, action_id, target_action, reactive_window) if is_player else base_actor
    var target: Dictionary = opponent.stats if is_player else player
    var stamina: float = player_stamina if is_player else opponent_stamina
    var stamina_before: float = stamina
    var event: Dictionary = {
        "actor": "player" if is_player else "opponent",
        "action": action_id,
        "action_label": str(action.label),
        "target_action": target_action,
        "reactive": reactive_window,
        "hit": false,
        "miss": false,
        "guard": false,
        "damage": 0.0,
        "target_stamina_damage": 0.0,
        "stamina_delta": 0.0,
        "knockout": false,
        "matchup": "",
        "plan_read": _plan_read_state(is_player, action_id, target_action, reactive_window)
    }

    if action_id == "guard":
        stamina = min(100.0, stamina - float(action.stamina))
        if is_player:
            player_stamina = stamina
            player_round_score += float(action.score)
        else:
            opponent_stamina = stamina
            opponent_round_score += float(action.score)
        event["guard"] = true
        event["stamina_delta"] = stamina - stamina_before
        log.append(("나" if is_player else str(opponent.name)) + " 가드")
        return event

    var cost: float = float(action.stamina) * (1.10 - float(actor.conditioning) / 500.0)
    stamina = max(0.0, stamina - cost)
    if is_player:
        player_stamina = stamina
    else:
        opponent_stamina = stamina
    event["stamina_delta"] = stamina - stamina_before

    var accuracy: float = float(action.accuracy)
    accuracy += (float(actor.technique) - float(target.defense)) * 0.003
    accuracy += (float(actor.speed) - float(target.speed)) * 0.0015
    accuracy += float(actor.get("modifiers", {}).get("accuracy_bonus", 0.0))
    accuracy -= max(0.0, 45.0 - stamina) * float(balance.fight.fatigue_accuracy_penalty)

    var damage_mult: float = 1.0
    if reactive_window and action_id == "counter" and target_action == "power":
        accuracy += float(balance.matchups.counter_vs_power.accuracy)
        damage_mult *= float(balance.matchups.counter_vs_power.damage)
        event["matchup"] = "counter_vs_power"
    elif reactive_window and action_id == "counter" and target_action == "body":
        accuracy += float(balance.matchups.counter_vs_body.accuracy)
        damage_mult *= float(balance.matchups.counter_vs_body.damage)
        event["matchup"] = "counter_vs_body"
    elif action_id == "jab" and target_action == "counter":
        accuracy += float(balance.matchups.jab_vs_counter.accuracy)
        damage_mult *= float(balance.matchups.jab_vs_counter.damage)
        event["matchup"] = "jab_vs_counter"
    elif action_id == "power" and target_action == "guard":
        accuracy += float(balance.matchups.power_vs_guard.accuracy)
        damage_mult *= float(balance.matchups.power_vs_guard.damage)
        event["matchup"] = "power_vs_guard"
    elif action_id == "body" and target_action == "guard":
        accuracy += float(balance.matchups.body_vs_guard.accuracy)
        damage_mult *= float(balance.matchups.body_vs_guard.damage)
        event["matchup"] = "body_vs_guard"

    accuracy = clamp(accuracy, 0.18, 0.93)
    event["accuracy"] = accuracy
    if rng.randf() > accuracy:
        event["miss"] = true
        log.append(("나" if is_player else str(opponent.name)) + " " + str(action.label) + " 빗나감")
        return event

    var damage: float = float(action.damage)
    damage *= 0.62 + float(actor.power) / 100.0 * 0.72
    damage *= 0.86 + float(actor.technique) / 100.0 * 0.22
    damage *= damage_mult
    damage *= rng.randf_range(0.88, 1.12)
    damage *= 1.0 - max(0.0, 35.0 - stamina) * float(balance.fight.fatigue_damage_penalty)
    if target_action == "guard":
        damage *= float(balance.fight.guard_mitigation)

    var target_stamina_before: float = opponent_stamina if is_player else player_stamina
    if is_player:
        opponent_hp = max(0.0, opponent_hp - damage)
        opponent_stamina = max(0.0, opponent_stamina - float(action.body_stamina_damage))
        player_round_score += damage * float(action.score)
    else:
        player_hp = max(0.0, player_hp - damage)
        player_stamina = max(0.0, player_stamina - float(action.body_stamina_damage))
        opponent_round_score += damage * float(action.score)
    var target_stamina_after: float = opponent_stamina if is_player else player_stamina

    event["hit"] = true
    event["damage"] = damage
    event["target_stamina_damage"] = max(0.0, target_stamina_before - target_stamina_after)
    log.append(("나" if is_player else str(opponent.name)) + " " + str(action.label) + " 적중 %.1f" % damage)
    event["knockout"] = _check_ko(is_player, damage)
    return event

func _actor_for_action(base_actor: Dictionary, action_id: String, target_action: String, reactive_window: bool) -> Dictionary:
    var plan: Dictionary = base_actor.get("game_plan", {})
    var action_modifiers: Dictionary = plan.get("action_modifiers", {})
    var modifiers: Dictionary = action_modifiers.get(action_id, {})
    if modifiers.is_empty():
        return base_actor
    var required: Array = modifiers.get("requires_target_actions", [])
    var source: Dictionary = modifiers
    if not required.is_empty() and (not reactive_window or not target_action in required):
        source = modifiers.get("miss_read_stats", {})
        if source.is_empty():
            return base_actor
    var adjusted: Dictionary = base_actor.duplicate(true)
    for stat in TRAINABLE_STATS:
        if source.has(stat):
            adjusted[stat] = clamp(int(adjusted.get(stat, 50)) + int(source[stat]), 1, 100)
    return adjusted

func _plan_read_state(is_player: bool, action_id: String, target_action: String, reactive_window: bool) -> String:
    if not is_player or action_id != "counter":
        return "none"
    var plan: Dictionary = player.get("game_plan", {})
    if str(plan.get("id", "")) != "counter_trap":
        return "none"
    if reactive_window and target_action in COMMITTED_ATTACKS:
        return "success"
    return "failed"

func _check_ko(attacker_is_player: bool, damage: float) -> bool:
    var target_hp: float = opponent_hp if attacker_is_player else player_hp
    var target: Dictionary = opponent.stats if attacker_is_player else player
    if target_hp <= 0.0:
        finished = true
        result = "WIN_KO" if attacker_is_player else "LOSS_KO"
        return true
    if damage < 10.0:
        return false
    var chin: float = (float(target.defense) + float(target.conditioning)) * 0.5
    var chance: float = float(balance.fight.ko_base_threshold)
    chance += max(0.0, damage - 10.0) * float(balance.fight.ko_damage_scale)
    chance += max(0.0, 45.0 - chin) * 0.004
    chance += max(0.0, 35.0 - target_hp) * 0.008
    chance *= float(target.get("modifiers", {}).get("ko_taken_multiplier", 1.0))
    if rng.randf() < clamp(chance, 0.0, 0.72):
        finished = true
        result = "WIN_KO" if attacker_is_player else "LOSS_KO"
        return true
    return false

func _score_round() -> void:
    if abs(player_round_score - opponent_round_score) < 0.75:
        cards.append([10, 10])
    elif player_round_score > opponent_round_score:
        cards.append([10, 9])
    else:
        cards.append([9, 10])

func _finish_decision() -> void:
    var p_total: int = 0
    var o_total: int = 0
    for card in cards:
        p_total += int(card[0])
        o_total += int(card[1])
    finished = true
    if p_total > o_total:
        result = "WIN_DEC"
    elif o_total > p_total:
        result = "LOSS_DEC"
    else:
        result = "DRAW"

func _choose_opponent_action() -> String:
    var tendencies: Dictionary = opponent.get("tendencies", {})
    if not tendencies.is_empty():
        var total: float = 0.0
        for action_id in ACTION_ORDER:
            total += max(0.0, float(tendencies.get(action_id, 0.0)))
        if total > 0.0:
            var weighted_roll: float = rng.randf() * total
            var cursor: float = 0.0
            for action_id in ACTION_ORDER:
                cursor += max(0.0, float(tendencies.get(action_id, 0.0)))
                if weighted_roll <= cursor:
                    return str(action_id)

    var style: String = str(opponent.style)
    var roll: float = rng.randf()
    if style == "swarmer":
        if roll < 0.34: return "body"
        if roll < 0.64: return "jab"
        if roll < 0.84: return "power"
        if roll < 0.94: return "guard"
        return "counter"
    if style == "out_boxer":
        if roll < 0.48: return "jab"
        if roll < 0.67: return "guard"
        if roll < 0.83: return "counter"
        if roll < 0.93: return "body"
        return "power"
    if style == "slugger":
        if roll < 0.48: return "power"
        if roll < 0.70: return "body"
        if roll < 0.82: return "jab"
        if roll < 0.92: return "guard"
        return "counter"
    if roll < 0.38: return "counter"
    if roll < 0.64: return "jab"
    if roll < 0.80: return "guard"
    if roll < 0.91: return "body"
    return "power"

func _build_telegraph(action_id: String) -> Dictionary:
    var tendencies: Dictionary = opponent.get("tendencies", {})
    var observed_probability: float = float(tendencies.get(action_id, 0.0))
    var confidence: int = int(clamp(round(45.0 + observed_probability * 50.0), 48.0, 78.0))
    var telegraph: Dictionary = {
        "action_id": action_id,
        "signal_id": "neutral",
        "title": "상대 움직임 관찰 중",
        "copy": "상대가 리듬을 숨기고 있습니다.",
        "cue": "짧은 공격과 수비 전환을 모두 열어 두세요.",
        "confidence": confidence
    }
    match action_id:
        "jab":
            telegraph["signal_id"] = "lead_hand"
            telegraph["title"] = "앞손이 먼저 움직입니다"
            telegraph["copy"] = "상대가 앞손으로 거리를 재며 리듬을 잡습니다."
            telegraph["cue"] = "짧은 공격 또는 거리 리셋 가능성."
        "power":
            telegraph["signal_id"] = "committed_attack"
            telegraph["title"] = "어깨에 힘이 실립니다"
            telegraph["copy"] = "뒷손과 체중이 뒤쪽에 실리며 큰 공격을 준비합니다."
            telegraph["cue"] = "강타 가능성. 가드 또는 반응형 카운터를 고려하세요."
        "body":
            telegraph["signal_id"] = "level_change"
            telegraph["title"] = "무게중심이 내려갑니다"
            telegraph["copy"] = "상대의 시선과 상체가 몸통 라인으로 낮아집니다."
            telegraph["cue"] = "바디 공격 가능성. 맞으면 스태미나 손실이 큽니다."
        "guard":
            telegraph["signal_id"] = "defensive_shell"
            telegraph["title"] = "가드가 닫힙니다"
            telegraph["copy"] = "상대가 팔꿈치와 장갑을 붙이며 피해를 줄이려 합니다."
            telegraph["cue"] = "정면 강타 효율이 낮아질 수 있습니다."
        "counter":
            telegraph["signal_id"] = "counter_wait"
            telegraph["title"] = "상대가 기다립니다"
            telegraph["copy"] = "먼저 들어오지 않고 당신의 큰 동작을 보고 반응하려 합니다."
            telegraph["cue"] = "욕심낸 강타보다 잽이나 안전한 운영이 유리할 수 있습니다."
    return telegraph

func _body_state_id(stamina: float) -> String:
    if stamina <= 20.0:
        return "critical"
    if stamina <= 40.0:
        return "hurt"
    if stamina <= 65.0:
        return "strained"
    return "stable"

func snapshot() -> Dictionary:
    return {
        "round": round_no,
        "exchange": exchange_no,
        "player_hp": player_hp,
        "opponent_hp": opponent_hp,
        "player_stamina": player_stamina,
        "opponent_stamina": opponent_stamina,
        "cards": cards.duplicate(true),
        "finished": finished,
        "result": result,
        "last_log": log.slice(max(0, log.size() - 5), log.size()),
        "pending_telegraph": pending_telegraph.duplicate(true),
        "last_exchange": last_exchange.duplicate(true)
    }

func export_state() -> Dictionary:
    return {
        "round_no": round_no,
        "exchange_no": exchange_no,
        "player_hp": player_hp,
        "opponent_hp": opponent_hp,
        "player_stamina": player_stamina,
        "opponent_stamina": opponent_stamina,
        "player_round_score": player_round_score,
        "opponent_round_score": opponent_round_score,
        "cards": cards.duplicate(true),
        "finished": finished,
        "result": result,
        "log": log.duplicate(),
        "pending_opponent_action": pending_opponent_action,
        "pending_telegraph": pending_telegraph.duplicate(true),
        "last_exchange": last_exchange.duplicate(true),
        "rng_state": str(rng.state)
    }

func restore(player_stats: Dictionary, opponent_data: Dictionary, saved: Dictionary) -> void:
    player = player_stats.duplicate(true)
    opponent = opponent_data.duplicate(true)
    round_no = int(saved.get("round_no", 1))
    exchange_no = int(saved.get("exchange_no", 0))
    player_hp = float(saved.get("player_hp", 100.0))
    opponent_hp = float(saved.get("opponent_hp", 100.0))
    player_stamina = float(saved.get("player_stamina", 100.0))
    opponent_stamina = float(saved.get("opponent_stamina", 100.0))
    player_round_score = float(saved.get("player_round_score", 0.0))
    opponent_round_score = float(saved.get("opponent_round_score", 0.0))
    cards = saved.get("cards", []).duplicate(true)
    finished = bool(saved.get("finished", false))
    result = str(saved.get("result", ""))
    pending_opponent_action = str(saved.get("pending_opponent_action", ""))
    pending_telegraph = saved.get("pending_telegraph", {}).duplicate(true)
    last_exchange = saved.get("last_exchange", {}).duplicate(true)
    log.clear()
    for entry in saved.get("log", []):
        log.append(str(entry))
    if saved.has("rng_state"):
        rng.state = int(str(saved.rng_state))

static func _load_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
