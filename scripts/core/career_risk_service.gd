class_name CareerRiskService
extends RefCounted

const CONFIG_PATH := "res://data/career_risk.json"
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

static func ensure_state(state: Dictionary) -> void:
    if state.is_empty():
        return
    var career_state: Dictionary = {}
    if typeof(state.get("career_state", {})) == TYPE_DICTIONARY:
        career_state = state.get("career_state", {}).duplicate(true)
    career_state["career_damage"] = max(0, int(career_state.get("career_damage", 0)))
    if not career_state.has("injuries") or typeof(career_state.get("injuries")) != TYPE_ARRAY:
        career_state["injuries"] = []
    if not career_state.has("damage_milestones") or typeof(career_state.get("damage_milestones")) != TYPE_ARRAY:
        career_state["damage_milestones"] = []
    career_state["health_ceiling"] = clamp(int(career_state.get("health_ceiling", 100)), 1, 100)
    career_state["recovery_penalty"] = max(0, int(career_state.get("recovery_penalty", 0)))
    state["career_state"] = career_state
    _enforce_health_ceiling(state)

static func fight_damage_delta(state: Dictionary, result: String, snapshot: Dictionary = {}) -> int:
    var config: Dictionary = _config()
    var rules: Dictionary = config.get("fight_damage", {})
    var delta: int = int(rules.get("base", 0))
    if result == "LOSS_KO":
        delta += int(rules.get("loss", 0)) + int(rules.get("loss_ko", 0))
    elif result.begins_with("LOSS"):
        delta += int(rules.get("loss", 0))
    elif result == "WIN_KO":
        delta += int(rules.get("win_ko", 0))
    if snapshot.has("player_hp"):
        var hp_loss: float = max(0.0, 100.0 - float(snapshot.get("player_hp", 100.0)))
        var divisor: float = max(1.0, float(rules.get("hp_divisor", 18.0)))
        delta += int(round(hp_loss / divisor))
    var fatigue: int = int(state.get("boxer", {}).get("fatigue", 0))
    if fatigue >= int(rules.get("high_fatigue_threshold", 75)):
        delta += int(rules.get("high_fatigue", 0))
    return max(0, delta)

static func apply_fight_damage(state: Dictionary, result: String, snapshot: Dictionary = {}) -> Dictionary:
    ensure_state(state)
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    var before: int = int(career_state.get("career_damage", 0))
    var delta: int = fight_damage_delta(state, result, snapshot)
    var after: int = before + delta
    career_state["career_damage"] = after
    state["career_state"] = career_state
    var added: Array = _apply_new_milestones(state)
    _enforce_health_ceiling(state)
    return {"before":before,"delta":delta,"after":int(state.get("career_state", {}).get("career_damage", after)),"new_chronic_injuries":added,"health_ceiling":health_ceiling(state),"recovery_penalty":recovery_penalty(state)}

static func apply_recovery_limits(state: Dictionary, before_health: int, before_fatigue: int) -> void:
    ensure_state(state)
    var boxer: Dictionary = state.get("boxer", {})
    var penalty: int = recovery_penalty(state)
    var after_health: int = int(boxer.get("health", before_health))
    if after_health > before_health and penalty > 0:
        boxer["health"] = max(before_health, after_health - penalty)
    var after_fatigue: int = int(boxer.get("fatigue", before_fatigue))
    if after_fatigue < before_fatigue and penalty > 0:
        var recovered: int = before_fatigue - after_fatigue
        var adjusted_recovery: int = max(0, recovered - penalty * 2)
        boxer["fatigue"] = max(0, before_fatigue - adjusted_recovery)
    _enforce_health_ceiling(state)

static func health_ceiling(state: Dictionary) -> int:
    _ensure_state_shallow(state)
    return clamp(int(state.get("career_state", {}).get("health_ceiling", 100)), 1, 100)

static func recovery_penalty(state: Dictionary) -> int:
    _ensure_state_shallow(state)
    return max(0, int(state.get("career_state", {}).get("recovery_penalty", 0)))

static func career_damage(state: Dictionary) -> int:
    _ensure_state_shallow(state)
    return max(0, int(state.get("career_state", {}).get("career_damage", 0)))

static func chronic_injuries(state: Dictionary) -> Array:
    _ensure_state_shallow(state)
    var values: Variant = state.get("career_state", {}).get("injuries", [])
    return values.duplicate(true) if typeof(values) == TYPE_ARRAY else []

static func forced_retirement_reached(state: Dictionary) -> bool:
    return career_damage(state) >= int(_config().get("forced_retirement_damage", 100))

static func _apply_new_milestones(state: Dictionary) -> Array:
    var config: Dictionary = _config()
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    var applied: Array = career_state.get("damage_milestones", []).duplicate(true)
    var injuries: Array = career_state.get("injuries", []).duplicate(true)
    var added: Array = []
    var damage: int = int(career_state.get("career_damage", 0))
    var boxer: Dictionary = state.get("boxer", {})
    var milestones: Array = config.get("milestones", [])
    for value in milestones:
        var milestone: Dictionary = value
        var milestone_id: String = str(milestone.get("id", ""))
        if milestone_id.is_empty() or milestone_id in applied or damage < int(milestone.get("threshold", 9999)):
            continue
        var penalties: Dictionary = milestone.get("stat_penalties", {})
        for stat in TRAINABLE_STATS:
            if penalties.has(stat):
                boxer[stat] = clamp(int(boxer.get(stat, 1)) + int(penalties[stat]), 1, 100)
        var injury: Dictionary = {"id":milestone_id,"name":str(milestone.get("name", milestone_id)),"chronic":true,"threshold":int(milestone.get("threshold", 0)),"stat_penalties":penalties.duplicate(true),"health_ceiling_penalty":int(milestone.get("health_ceiling_penalty", 0)),"recovery_penalty":int(milestone.get("recovery_penalty", 0))}
        injuries.append(injury)
        applied.append(milestone_id)
        added.append(injury.duplicate(true))
        career_state["health_ceiling"] = max(1, int(career_state.get("health_ceiling", 100)) - int(milestone.get("health_ceiling_penalty", 0)))
        career_state["recovery_penalty"] = int(career_state.get("recovery_penalty", 0)) + int(milestone.get("recovery_penalty", 0))
    career_state["injuries"] = injuries
    career_state["damage_milestones"] = applied
    state["career_state"] = career_state
    return added

static func _enforce_health_ceiling(state: Dictionary) -> void:
    if state.is_empty() or typeof(state.get("boxer", {})) != TYPE_DICTIONARY:
        return
    var ceiling: int = clamp(int(state.get("career_state", {}).get("health_ceiling", 100)), 1, 100)
    var boxer: Dictionary = state.get("boxer", {})
    boxer["health"] = min(int(boxer.get("health", ceiling)), ceiling)

static func _ensure_state_shallow(state: Dictionary) -> void:
    if state.is_empty():
        return
    var career_state: Dictionary = state.get("career_state", {})
    if not career_state.has("career_damage"): career_state["career_damage"] = 0
    if not career_state.has("injuries"): career_state["injuries"] = []
    if not career_state.has("damage_milestones"): career_state["damage_milestones"] = []
    if not career_state.has("health_ceiling"): career_state["health_ceiling"] = 100
    if not career_state.has("recovery_penalty"): career_state["recovery_penalty"] = 0
    state["career_state"] = career_state

static func _config() -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
