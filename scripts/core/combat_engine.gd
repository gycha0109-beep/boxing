class_name CombatEngine
extends RefCounted

const ACTION_ORDER := ["jab", "power", "body", "guard", "counter"]
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

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

func resolve_exchange(player_action: String) -> Dictionary:
    if finished:
        return snapshot()
    var opponent_action: String = _choose_opponent_action()
    exchange_no += 1
    player_round_score = 0.0 if exchange_no % int(balance.fight.exchanges_per_round) == 1 else player_round_score
    opponent_round_score = 0.0 if exchange_no % int(balance.fight.exchanges_per_round) == 1 else opponent_round_score

    var p_speed: float = float(player.speed) + rng.randf_range(-10.0, 10.0)
    var o_speed: float = float(opponent.stats.speed) + rng.randf_range(-10.0, 10.0)
    var first_is_player: bool = p_speed >= o_speed

    if first_is_player:
        _perform(true, player_action, opponent_action)
        if not finished:
            _perform(false, opponent_action, player_action)
    else:
        _perform(false, opponent_action, player_action)
        if not finished:
            _perform(true, player_action, opponent_action)

    if not finished and exchange_no % int(balance.fight.exchanges_per_round) == 0:
        _score_round()
        if round_no >= int(balance.fight.rounds):
            _finish_decision()
        else:
            round_no += 1
            player_stamina = min(100.0, player_stamina + 9.0 + float(player.conditioning) * 0.05)
            opponent_stamina = min(100.0, opponent_stamina + 9.0 + float(opponent.stats.conditioning) * 0.05)

    var out: Dictionary = snapshot()
    out["opponent_action"] = opponent_action
    return out

func _perform(is_player: bool, action_id: String, target_action: String) -> void:
    var actions: Dictionary = balance.actions
    if not actions.has(action_id):
        return
    var action: Dictionary = actions[action_id]
    var base_actor: Dictionary = player if is_player else opponent.stats
    var actor: Dictionary = _actor_for_action(base_actor, action_id, target_action) if is_player else base_actor
    var target: Dictionary = opponent.stats if is_player else player
    var stamina: float = player_stamina if is_player else opponent_stamina

    if action_id == "guard":
        stamina = min(100.0, stamina - float(action.stamina))
        if is_player:
            player_stamina = stamina
            player_round_score += float(action.score)
        else:
            opponent_stamina = stamina
            opponent_round_score += float(action.score)
        log.append(("나" if is_player else str(opponent.name)) + " 가드")
        return

    var cost: float = float(action.stamina) * (1.10 - float(actor.conditioning) / 500.0)
    stamina = max(0.0, stamina - cost)
    if is_player:
        player_stamina = stamina
    else:
        opponent_stamina = stamina

    var accuracy: float = float(action.accuracy)
    accuracy += (float(actor.technique) - float(target.defense)) * 0.003
    accuracy += (float(actor.speed) - float(target.speed)) * 0.0015
    accuracy += float(actor.get("modifiers", {}).get("accuracy_bonus", 0.0))
    accuracy -= max(0.0, 45.0 - stamina) * float(balance.fight.fatigue_accuracy_penalty)

    var damage_mult: float = 1.0
    if action_id == "counter" and target_action == "power":
        accuracy += float(balance.matchups.counter_vs_power.accuracy)
        damage_mult *= float(balance.matchups.counter_vs_power.damage)
    elif action_id == "counter" and target_action == "body":
        accuracy += float(balance.matchups.counter_vs_body.accuracy)
        damage_mult *= float(balance.matchups.counter_vs_body.damage)
    elif action_id == "jab" and target_action == "counter":
        accuracy += float(balance.matchups.jab_vs_counter.accuracy)
        damage_mult *= float(balance.matchups.jab_vs_counter.damage)
    elif action_id == "power" and target_action == "guard":
        accuracy += float(balance.matchups.power_vs_guard.accuracy)
        damage_mult *= float(balance.matchups.power_vs_guard.damage)
    elif action_id == "body" and target_action == "guard":
        accuracy += float(balance.matchups.body_vs_guard.accuracy)
        damage_mult *= float(balance.matchups.body_vs_guard.damage)

    accuracy = clamp(accuracy, 0.18, 0.93)
    if rng.randf() > accuracy:
        log.append(("나" if is_player else str(opponent.name)) + " " + str(action.label) + " 빗나감")
        return

    var damage: float = float(action.damage)
    damage *= 0.62 + float(actor.power) / 100.0 * 0.72
    damage *= 0.86 + float(actor.technique) / 100.0 * 0.22
    damage *= damage_mult
    damage *= rng.randf_range(0.88, 1.12)
    damage *= 1.0 - max(0.0, 35.0 - stamina) * float(balance.fight.fatigue_damage_penalty)
    if target_action == "guard":
        damage *= float(balance.fight.guard_mitigation)

    if is_player:
        opponent_hp = max(0.0, opponent_hp - damage)
        opponent_stamina = max(0.0, opponent_stamina - float(action.body_stamina_damage))
        player_round_score += damage * float(action.score)
    else:
        player_hp = max(0.0, player_hp - damage)
        player_stamina = max(0.0, player_stamina - float(action.body_stamina_damage))
        opponent_round_score += damage * float(action.score)

    log.append(("나" if is_player else str(opponent.name)) + " " + str(action.label) + " 적중 %.1f" % damage)
    _check_ko(is_player, damage)

func _actor_for_action(base_actor: Dictionary, action_id: String, target_action: String) -> Dictionary:
    var plan: Dictionary = base_actor.get("game_plan", {})
    var action_modifiers: Dictionary = plan.get("action_modifiers", {})
    var modifiers: Dictionary = action_modifiers.get(action_id, {})
    if modifiers.is_empty():
        return base_actor
    var required: Array = modifiers.get("requires_target_actions", [])
    if not required.is_empty() and not target_action in required:
        return base_actor
    var adjusted: Dictionary = base_actor.duplicate(true)
    for stat in TRAINABLE_STATS:
        if modifiers.has(stat):
            adjusted[stat] = clamp(int(adjusted.get(stat, 50)) + int(modifiers[stat]), 1, 100)
    return adjusted

func _check_ko(attacker_is_player: bool, damage: float) -> void:
    var target_hp: float = opponent_hp if attacker_is_player else player_hp
    var target: Dictionary = opponent.stats if attacker_is_player else player
    if target_hp <= 0.0:
        finished = true
        result = "WIN_KO" if attacker_is_player else "LOSS_KO"
        return
    if damage < 10.0:
        return
    var chin: float = (float(target.defense) + float(target.conditioning)) * 0.5
    var chance: float = float(balance.fight.ko_base_threshold)
    chance += max(0.0, damage - 10.0) * float(balance.fight.ko_damage_scale)
    chance += max(0.0, 45.0 - chin) * 0.004
    chance += max(0.0, 35.0 - target_hp) * 0.008
    chance *= float(target.get("modifiers", {}).get("ko_taken_multiplier", 1.0))
    if rng.randf() < clamp(chance, 0.0, 0.72):
        finished = true
        result = "WIN_KO" if attacker_is_player else "LOSS_KO"

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
        "last_log": log.slice(max(0, log.size() - 5), log.size())
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
    log.clear()
    for entry in saved.get("log", []):
        log.append(str(entry))
    if saved.has("rng_state"):
        rng.state = int(str(saved.rng_state))

static func _load_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
