extends Node

const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

var state: Dictionary = {}
var career_balance: Dictionary = {}
var traits: Array = []
var events: Array = []
var injuries: Array = []
var fighter_identities: Array = []
var game_plans: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    career_balance = _load_json_dict("res://data/career_balance.json")
    traits = _load_json_array("res://data/traits.json")
    events = _load_json_array("res://data/events.json")
    injuries = _load_json_array("res://data/injuries.json")
    fighter_identities = _load_json_array("res://data/fighter_identities.json")
    game_plans = _load_json_array("res://data/game_plans.json")
    rng.seed = Time.get_ticks_usec()
    var loaded: Dictionary = SaveService.load_game()
    if loaded.is_empty():
        new_career("무명 복서")
    else:
        state = loaded
        var normalized: bool = _normalize_v03_state()
        _sync_progression()
        if normalized:
            SaveService.save_game(state)

func new_career(boxer_name: String, trait_id: String = "") -> void:
    var trait_data: Dictionary = _pick_trait(trait_id)
    var identity: Dictionary = _pick_identity()
    var base_boxer: Dictionary = {
        "name": boxer_name,
        "power": 50,
        "speed": 50,
        "technique": 50,
        "defense": 50,
        "conditioning": 50,
        "fatigue": 0,
        "health": 100,
        "weight_kg": float(career_balance.weight_class.start_weight_kg),
        "trait_id": str(trait_data.get("id", "")),
        "trait_name": str(trait_data.get("name", "무특성")),
        "modifiers": trait_data.get("modifiers", {}).duplicate(true),
        "injury": {},
        "identity_id": str(identity.get("id", "balanced")),
        "identity_name": str(identity.get("name", "균형형")),
        "identity_description": str(identity.get("description", "")),
        "identity_signature": str(identity.get("signature", ""))
    }
    for stat in TRAINABLE_STATS:
        var trait_bonus: int = int(trait_data.get("stat_bonus", {}).get(stat, 0))
        var identity_bonus: int = int(identity.get("stat_bonus", {}).get(stat, 0))
        base_boxer[stat] = clamp(int(base_boxer[stat]) + trait_bonus + identity_bonus, 1, 100)

    state = {
        "phase": "camp",
        "boxer": base_boxer,
        "career": {
            "age_months": 19 * 12,
            "money": 120000,
            "reputation": 0,
            "wins": 0,
            "losses": 0,
            "draws": 0,
            "fights": 0,
            "career_points": 0,
            "tier": "prospect",
            "rank": 50,
            "champion": false,
            "finished": false,
            "ending": ""
        },
        "last_camp_action": "",
        "selected_opponent": "",
        "selected_game_plan": "",
        "last_result": "",
        "last_fight_summary": {},
        "last_weigh_in": {},
        "pending_event": {},
        "fight_seed": 0,
        "active_fight": {}
    }
    _sync_progression()
    SaveService.save_game(state)

func apply_camp_action(action: Dictionary) -> Dictionary:
    if str(state.get("phase", "")) != "camp":
        return {"ok": false, "reason": "wrong_phase"}
    var career: Dictionary = state.career
    var boxer: Dictionary = state.boxer
    var cost: int = int(action.get("cost", 0))
    if int(career.money) < cost:
        return {"ok": false, "reason": "money"}

    career.money -= cost
    var effects: Dictionary = action.get("effects", {})
    var growth_multiplier: float = float(boxer.modifiers.get("growth_multiplier", 1.0))
    for stat in TRAINABLE_STATS:
        if effects.has(stat):
            var raw_gain: int = int(effects[stat])
            var gain: int = raw_gain
            if raw_gain > 0:
                gain = max(1, int(round(float(raw_gain) * growth_multiplier)))
            boxer[stat] = clamp(int(boxer[stat]) + gain, 1, 100)

    var fatigue_delta: int = int(effects.get("fatigue", 0))
    if fatigue_delta > 0 and str(action.get("kind", "training")) == "training":
        fatigue_delta = int(round(float(fatigue_delta) * float(boxer.modifiers.get("training_fatigue_multiplier", 1.0))))
    boxer.fatigue = clamp(int(boxer.fatigue) + fatigue_delta, 0, 100)
    boxer.health = clamp(int(boxer.health) + int(effects.get("health", 0)), 0, 100)
    boxer.weight_kg = clamp(float(boxer.weight_kg) + float(effects.get("weight", 0.0)), 57.0, 68.0)

    if effects.has("injury_camps") and not boxer.injury.is_empty():
        boxer.injury.remaining_camps = max(0, int(boxer.injury.remaining_camps) + int(effects.injury_camps))
        if int(boxer.injury.remaining_camps) <= 0:
            boxer.injury = {}

    if float(action.get("risk", 0.0)) > 0.0:
        var risk: float = float(career_balance.injury.base_training_chance) + float(action.risk)
        if int(boxer.fatigue) >= 75:
            risk += float(career_balance.injury.high_fatigue_bonus)
        risk *= float(boxer.modifiers.get("injury_risk_multiplier", 1.0))
        if rng.randf() < risk:
            _assign_random_injury()

    state.last_camp_action = str(action.id)
    state.phase = "fight_offer"
    SaveService.save_game(state)
    return {"ok": true}

func get_fight_offers(all_opponents: Array) -> Array:
    var current_tier: String = str(state.career.tier)
    var current_index: int = _tier_index(current_tier)
    var same: Array = []
    var lower: Array = []
    var higher: Array = []
    for opponent in all_opponents:
        var index: int = _tier_index(str(opponent.tier))
        if str(opponent.tier) == "title" and int(state.career.career_points) < 88:
            continue
        if index == current_index:
            same.append(opponent)
        elif index == current_index - 1:
            lower.append(opponent)
        elif index == current_index + 1:
            higher.append(opponent)

    var offers: Array = []
    if not lower.is_empty():
        offers.append(lower[0])
    for opponent in same:
        if offers.size() < 2:
            offers.append(opponent)
    if not higher.is_empty() and offers.size() < 3:
        offers.append(higher[0])
    for opponent in same:
        if offers.size() >= 3:
            break
        if not offers.has(opponent):
            offers.append(opponent)
    for opponent in higher:
        if offers.size() >= 3:
            break
        if not offers.has(opponent):
            offers.append(opponent)
    return offers

func select_opponent(opponent: Dictionary) -> void:
    state.selected_opponent = str(opponent.id)
    state.selected_game_plan = ""
    state.last_weigh_in = {}
    state.fight_seed = 0
    state.active_fight = {}
    state.phase = "game_plan"
    SaveService.save_game(state)

func select_game_plan(plan_id: String) -> Dictionary:
    if str(state.get("phase", "")) != "game_plan":
        return {"ok": false, "reason": "wrong_phase"}
    var plan: Dictionary = get_game_plan(plan_id)
    if plan.is_empty():
        return {"ok": false, "reason": "unknown_plan"}
    state.selected_game_plan = str(plan.id)
    state.last_weigh_in = _resolve_weigh_in()
    state.fight_seed = rng.randi()
    state.active_fight = {}
    state.phase = "fight"
    SaveService.save_game(state)
    return {"ok": true, "plan": plan}

func save_active_fight(active: Dictionary) -> void:
    if str(state.get("phase", "")) != "fight":
        return
    state.active_fight = active.duplicate(true)
    SaveService.save_game(state)

func get_fight_boxer() -> Dictionary:
    var boxer: Dictionary = state.boxer.duplicate(true)
    var injury: Dictionary = boxer.get("injury", {})
    if not injury.is_empty():
        for stat in TRAINABLE_STATS:
            if injury.get("penalties", {}).has(stat):
                boxer[stat] = clamp(int(boxer[stat]) + int(injury.penalties[stat]), 1, 100)

    var plan: Dictionary = get_selected_game_plan()
    var global_stats: Dictionary = plan.get("global_stats", {})
    for stat in TRAINABLE_STATS:
        if global_stats.has(stat):
            boxer[stat] = clamp(int(boxer[stat]) + int(global_stats[stat]), 1, 100)
    boxer["game_plan"] = plan.duplicate(true)
    return boxer

func get_selected_game_plan() -> Dictionary:
    var plan_id: String = str(state.get("selected_game_plan", ""))
    if plan_id.is_empty():
        plan_id = "balanced"
    return get_game_plan(plan_id)

func get_game_plan(plan_id: String) -> Dictionary:
    for plan in game_plans:
        if str(plan.id) == plan_id:
            return plan
    for plan in game_plans:
        if str(plan.id) == "balanced":
            return plan
    return {}

func identity_description() -> String:
    return str(state.get("boxer", {}).get("identity_description", "상대에 맞춰 스타일을 바꾸는 복서"))

func apply_fight_result(result: String, opponent: Dictionary, snapshot: Dictionary = {}) -> void:
    if str(state.get("phase", "")) != "fight":
        return
    var career: Dictionary = state.career
    var boxer: Dictionary = state.boxer
    var purse_multiplier: float = float(state.last_weigh_in.get("purse_multiplier", 1.0))
    purse_multiplier *= float(boxer.modifiers.get("purse_multiplier", 1.0))
    var gross_purse: int = int(round(float(opponent.purse) * purse_multiplier))
    var purse: int = int(round(float(gross_purse) * float(career_balance.economy.purse_net_multiplier)))
    var cycle_cost: int = int(career_balance.economy.cycle_cost_by_tier.get(str(opponent.tier), 0))

    career.fights += 1
    career.age_months += int(career_balance.calendar.months_per_fight)
    career.money += purse
    career.money -= cycle_cost

    var fight_fatigue: int = 14
    var fight_health_loss: int = 1
    if result == "LOSS_KO":
        fight_fatigue += 12
        fight_health_loss += 8
    elif result == "WIN_KO":
        fight_fatigue += 5
        fight_health_loss += 2
    elif result.begins_with("LOSS"):
        fight_fatigue += 7
        fight_health_loss += 4
    if snapshot.has("player_hp"):
        fight_health_loss += int(round(max(0.0, 100.0 - float(snapshot.player_hp)) / 20.0))

    boxer.fatigue = clamp(int(boxer.fatigue) + fight_fatigue, 0, 100)
    boxer.health = clamp(int(boxer.health) - fight_health_loss, 0, 100)
    boxer.weight_kg = clamp(float(boxer.weight_kg) + 0.35, 57.0, 68.0)

    var reputation_multiplier: float = float(boxer.modifiers.get("reputation_multiplier", 1.0))
    if result.begins_with("WIN"):
        career.wins += 1
        career.reputation += int(round(float(opponent.reputation_reward) * reputation_multiplier))
        career.career_points += int(opponent.career_points_win)
        if bool(opponent.get("title_fight", false)):
            career.champion = true
            career.finished = true
            career.ending = "world_champion"
    elif result.begins_with("LOSS"):
        career.losses += 1
        career.reputation = max(0, int(career.reputation) - 2)
        career.career_points -= int(opponent.career_points_loss)
    else:
        career.draws += 1
        career.career_points += max(1, int(opponent.career_points_win) / 3)

    career.career_points = clamp(int(career.career_points), int(career_balance.career_points.min), int(career_balance.career_points.max))
    state.last_result = result
    state.active_fight = {}
    state.last_fight_summary = {
        "opponent_id": str(opponent.id),
        "opponent_name": str(opponent.name),
        "gross_purse": gross_purse,
        "purse": purse,
        "cycle_cost": cycle_cost,
        "result": result,
        "player_hp": float(snapshot.get("player_hp", 0.0)),
        "opponent_hp": float(snapshot.get("opponent_hp", 0.0)),
        "weigh_in": state.last_weigh_in.duplicate(true),
        "game_plan": str(state.get("selected_game_plan", "balanced"))
    }

    _roll_fight_injury(result)
    _sync_progression()
    _check_retirement()
    state.phase = "career_summary" if bool(career.finished) else "result"
    SaveService.save_game(state)

func advance_after_result() -> void:
    if bool(state.career.finished):
        state.phase = "career_summary"
        SaveService.save_game(state)
        return
    state.pending_event = {}
    if rng.randf() < float(career_balance.events.post_fight_chance):
        var picked: Dictionary = _pick_event()
        if not picked.is_empty():
            state.pending_event = picked.duplicate(true)
            state.phase = "event"
            SaveService.save_game(state)
            return
    _begin_next_cycle()

func resolve_pending_event() -> void:
    var event: Dictionary = state.get("pending_event", {})
    if event.is_empty():
        _begin_next_cycle()
        return
    _apply_effects(event.get("effects", {}))
    state.pending_event = {}
    _check_retirement()
    if bool(state.career.finished):
        state.phase = "career_summary"
        SaveService.save_game(state)
    else:
        _begin_next_cycle()

func age_text() -> String:
    var months: int = int(state.career.age_months)
    return "%d세 %d개월" % [int(months / 12), months % 12]

func tier_label() -> String:
    var tier_id: String = str(state.career.tier)
    for tier in career_balance.career_points.tiers:
        if str(tier.id) == tier_id:
            return str(tier.label)
    return tier_id

func ending_text() -> String:
    match str(state.career.ending):
        "world_champion": return "세계 타이틀을 차지하고 커리어의 정점에 올랐습니다."
        "health_retirement": return "누적된 손상으로 더는 링에 오를 수 없어 은퇴했습니다."
        "loss_retirement": return "연패와 패배가 쌓여 프로 커리어를 끝냈습니다."
        "bankrupt": return "커리어 자금이 바닥나 훈련을 지속하지 못했습니다."
        "age_retirement": return "시간이 흘러 자연스럽게 글러브를 내려놓았습니다."
        "fight_limit": return "긴 커리어 끝에 스스로 은퇴를 선택했습니다."
        _: return "커리어가 종료되었습니다."

func _resolve_weigh_in() -> Dictionary:
    var boxer: Dictionary = state.boxer
    var limit: float = float(career_balance.weight_class.limit_kg)
    var over: float = float(boxer.weight_kg) - limit
    if over <= 0.0:
        return {"status":"pass", "over_kg": over, "purse_multiplier":1.0}
    if over <= float(career_balance.weigh_in.soft_over_kg):
        boxer.weight_kg = limit
        boxer.fatigue = clamp(int(boxer.fatigue) + int(career_balance.weigh_in.emergency_cut_fatigue), 0, 100)
        boxer.health = clamp(int(boxer.health) - int(career_balance.weigh_in.emergency_cut_health), 0, 100)
        return {"status":"emergency_cut", "over_kg": over, "purse_multiplier":1.0}
    state.career.reputation = max(0, int(state.career.reputation) - int(career_balance.weigh_in.miss_reputation_penalty))
    var multiplier: float = float(career_balance.weigh_in.miss_purse_multiplier)
    if float(boxer.weight_kg) >= float(career_balance.weight_class.hard_miss_kg):
        multiplier *= 0.75
    return {"status":"miss", "over_kg": over, "purse_multiplier":multiplier}

func _roll_fight_injury(result: String) -> void:
    var boxer: Dictionary = state.boxer
    var chance: float = float(career_balance.injury.base_fight_chance)
    if result == "LOSS_KO":
        chance += float(career_balance.injury.ko_loss_bonus)
    if int(boxer.fatigue) >= 75:
        chance += float(career_balance.injury.high_fatigue_bonus)
    chance *= float(boxer.modifiers.get("injury_risk_multiplier", 1.0))
    if rng.randf() < chance:
        _assign_random_injury()

func _assign_random_injury() -> void:
    if injuries.is_empty():
        return
    var injury: Dictionary = injuries[rng.randi_range(0, injuries.size() - 1)].duplicate(true)
    var current: Dictionary = state.boxer.injury
    if current.is_empty() or int(injury.remaining_camps) >= int(current.get("remaining_camps", 0)):
        state.boxer.injury = injury

func _assign_injury_by_id(injury_id: String) -> void:
    for injury in injuries:
        if str(injury.id) == injury_id:
            state.boxer.injury = injury.duplicate(true)
            return

func _pick_event() -> Dictionary:
    var candidates: Array = []
    var total_weight: float = 0.0
    for event in events:
        var requires: Dictionary = event.get("requires", {})
        var prefix: String = str(requires.get("last_result_prefix", ""))
        if not prefix.is_empty() and not str(state.last_result).begins_with(prefix):
            continue
        candidates.append(event)
        total_weight += float(event.get("weight", 1.0))
    if candidates.is_empty():
        return {}
    var roll: float = rng.randf() * total_weight
    var cursor: float = 0.0
    for event in candidates:
        cursor += float(event.get("weight", 1.0))
        if roll <= cursor:
            return event
    return candidates[-1]

func _apply_effects(effects: Dictionary) -> void:
    var boxer: Dictionary = state.boxer
    var career: Dictionary = state.career
    career.money += int(effects.get("money", 0))
    career.reputation = max(0, int(career.reputation) + int(effects.get("reputation", 0)))
    boxer.fatigue = clamp(int(boxer.fatigue) + int(effects.get("fatigue", 0)), 0, 100)
    boxer.health = clamp(int(boxer.health) + int(effects.get("health", 0)), 0, 100)
    if effects.has("injury"):
        _assign_injury_by_id(str(effects.injury))

func _begin_next_cycle() -> void:
    var boxer: Dictionary = state.boxer
    var recovery_bonus: int = int(boxer.modifiers.get("recovery_bonus", 0))
    boxer.fatigue = max(0, int(boxer.fatigue) - 12 - recovery_bonus)
    boxer.health = min(100, int(boxer.health) + 2 + int(recovery_bonus / 2))
    if not boxer.injury.is_empty():
        boxer.injury.remaining_camps = max(0, int(boxer.injury.remaining_camps) - 1)
        if int(boxer.injury.remaining_camps) <= 0:
            boxer.injury = {}
    state.selected_opponent = ""
    state.selected_game_plan = ""
    state.last_camp_action = ""
    state.last_weigh_in = {}
    state.fight_seed = 0
    state.active_fight = {}
    state.phase = "camp"
    _check_retirement()
    if bool(state.career.finished):
        state.phase = "career_summary"
    SaveService.save_game(state)

func _sync_progression() -> void:
    if state.is_empty() or career_balance.is_empty():
        return
    var career: Dictionary = state.career
    var points: int = int(career.get("career_points", 0))
    var tier_id: String = "prospect"
    for tier in career_balance.career_points.tiers:
        if points >= int(tier.min) and points <= int(tier.max):
            tier_id = str(tier.id)
            break
    career.tier = tier_id
    career.rank = max(1, 50 - int(round(float(points) * 0.49)))

func _check_retirement() -> void:
    var career: Dictionary = state.career
    var boxer: Dictionary = state.boxer
    if bool(career.get("finished", false)):
        return
    if int(boxer.health) <= int(career_balance.retirement.health_floor):
        career.finished = true
        career.ending = "health_retirement"
    elif int(career.losses) >= int(career_balance.retirement.loss_limit):
        career.finished = true
        career.ending = "loss_retirement"
    elif int(career.money) <= int(career_balance.retirement.debt_floor):
        career.finished = true
        career.ending = "bankrupt"
    elif int(career.age_months) >= int(career_balance.calendar.max_age_years) * 12:
        career.finished = true
        career.ending = "age_retirement"
    elif int(career.fights) >= int(career_balance.calendar.max_fights):
        career.finished = true
        career.ending = "fight_limit"

func _pick_trait(requested_id: String) -> Dictionary:
    if not requested_id.is_empty():
        for trait_data in traits:
            if str(trait_data.id) == requested_id:
                return trait_data
    if traits.is_empty():
        return {}
    return traits[rng.randi_range(0, traits.size() - 1)]

func _pick_identity() -> Dictionary:
    var candidates: Array = []
    for identity in fighter_identities:
        if str(identity.id) != "balanced":
            candidates.append(identity)
    if not candidates.is_empty():
        return candidates[rng.randi_range(0, candidates.size() - 1)]
    return _identity_by_id("balanced")

func _identity_by_id(identity_id: String) -> Dictionary:
    for identity in fighter_identities:
        if str(identity.id) == identity_id:
            return identity
    return {}

func _apply_identity(identity: Dictionary, apply_stats: bool) -> void:
    if identity.is_empty() or state.is_empty():
        return
    var boxer: Dictionary = state.boxer
    boxer["identity_id"] = str(identity.get("id", "balanced"))
    boxer["identity_name"] = str(identity.get("name", "균형형"))
    boxer["identity_description"] = str(identity.get("description", ""))
    boxer["identity_signature"] = str(identity.get("signature", ""))
    if apply_stats:
        var bonuses: Dictionary = identity.get("stat_bonus", {})
        for stat in TRAINABLE_STATS:
            if bonuses.has(stat):
                boxer[stat] = clamp(int(boxer.get(stat, 50)) + int(bonuses[stat]), 1, 100)

func _normalize_v03_state() -> bool:
    if state.is_empty():
        return false
    var changed: bool = false
    var boxer: Dictionary = state.boxer
    if not boxer.has("identity_id"):
        _apply_identity(_identity_by_id("balanced"), false)
        changed = true
    if not state.has("selected_game_plan"):
        state["selected_game_plan"] = "balanced" if str(state.get("phase", "")) == "fight" else ""
        changed = true
    if str(state.get("phase", "")) == "fight" and get_game_plan(str(state.get("selected_game_plan", ""))).is_empty():
        state.selected_game_plan = "balanced"
        changed = true
    if str(state.get("phase", "")) == "game_plan" and str(state.get("selected_opponent", "")).is_empty():
        state.phase = "fight_offer"
        changed = true
    return changed

func _tier_index(tier_id: String) -> int:
    var tiers: Array = career_balance.career_points.tiers
    for i in range(tiers.size()):
        if str(tiers[i].id) == tier_id:
            return i
    return 0

static func _load_json_dict(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

static func _load_json_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []
