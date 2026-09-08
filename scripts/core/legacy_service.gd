class_name LegacyService
extends RefCounted

const DEFINITIONS_PATH := "res://data/legacy_definitions.json"
const MAX_CANDIDATES := 3
const DIMINISHING_FACTOR := 0.5
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

static func observe_career_peak(state: Dictionary) -> void:
    if state.is_empty():
        return
    var career: Dictionary = state.get("career", {})
    if career.is_empty():
        return
    var career_state: Dictionary = {}
    if typeof(state.get("career_state", {})) == TYPE_DICTIONARY:
        career_state = state.get("career_state", {}).duplicate(true)
    var points := int(career.get("career_points", 0))
    var previous := int(career_state.get("career_high_points", -1))
    if points >= previous:
        career_state["career_high_points"] = points
        career_state["career_high_rank"] = int(career.get("rank", 50))
        career_state["career_high_tier"] = str(career.get("tier", "prospect"))
    elif previous >= 0:
        career_state["career_high_points"] = previous
        career_state["career_high_rank"] = int(career_state.get("career_high_rank", career.get("rank", 50)))
        career_state["career_high_tier"] = str(career_state.get("career_high_tier", career.get("tier", "prospect")))
    state["career_state"] = career_state

static func retirement_profile(state: Dictionary) -> Dictionary:
    observe_career_peak(state)
    var career: Dictionary = state.get("career", {})
    var career_state: Dictionary = state.get("career_state", {})
    var high_points := int(career_state.get("career_high_points", career.get("career_points", 0)))
    var ending := str(career.get("ending", ""))
    var champion := bool(career.get("champion", false)) or ending == "world_champion"

    var legacy_tier := "early_pro"
    var role := "동네 체육관 관장"
    if champion:
        legacy_tier = "world_class"
        role = "세계급 트레이너"
    elif high_points >= 75:
        legacy_tier = "title_contender"
        role = "유명 트레이너"
    elif high_points >= 40:
        legacy_tier = "ranked"
        role = "엘리트 코치"
    elif high_points >= 20:
        legacy_tier = "mid_pro"
        role = "프로 선수 코치"

    return {
        "legacy_tier": legacy_tier,
        "role": role,
        "career_high_points": high_points,
        "career_high_rank": int(career_state.get("career_high_rank", career.get("rank", 50))),
        "career_high_tier": str(career_state.get("career_high_tier", career.get("tier", "prospect"))),
        "flavor": _retirement_flavor(state),
    }

static func prepare_retirement_candidates(state: Dictionary) -> Array:
    if state.is_empty() or not bool(state.get("career", {}).get("finished", false)):
        return []
    observe_career_peak(state)
    var career_state: Dictionary = state.get("career_state", {})
    var stored: Array = career_state.get("retirement_legacy_candidates", [])
    if not stored.is_empty():
        return _definitions_for_ids(stored)

    var tier := str(retirement_profile(state).get("legacy_tier", "early_pro"))
    var candidates: Array = []
    for definition in definitions():
        if str(definition.get("tier", "")) == tier:
            candidates.append(definition)
            if candidates.size() >= MAX_CANDIDATES:
                break

    var ids: Array = []
    for candidate in candidates:
        ids.append(str(candidate.get("id", "")))
    career_state["retirement_legacy_candidates"] = ids
    state["career_state"] = career_state
    if not candidates.is_empty():
        SaveService.save_game(state)
    return candidates

static func select_retirement_legacy(state: Dictionary, definition_id: String) -> Dictionary:
    if state.is_empty() or not bool(state.get("career", {}).get("finished", false)):
        return {"ok": false, "reason": "career_not_finished"}

    var career_state: Dictionary = state.get("career_state", {})
    var selected: Dictionary = career_state.get("retirement_legacy_selected", {})
    if not selected.is_empty():
        return {"ok": false, "reason": "already_selected", "legacy": selected.duplicate(true)}
    var pending: Dictionary = career_state.get("retirement_legacy_pending", {})
    if not pending.is_empty():
        return {"ok": false, "reason": "slot_decision_pending", "legacy": pending.duplicate(true)}

    var candidates := prepare_retirement_candidates(state)
    var candidate_ids: Array[String] = []
    for candidate in candidates:
        candidate_ids.append(str(candidate.get("id", "")))
    if definition_id not in candidate_ids:
        return {"ok": false, "reason": "not_a_candidate"}

    var meta: Dictionary = state.get("meta_state", {}).duplicate(true)
    var slots: Array = meta.get("legacy_slots", []).duplicate(true)
    var capacity := int(meta.get("legacy_capacity", 3))
    var instance := _build_instance(state, definition_id, meta)

    if slots.size() >= capacity:
        career_state["retirement_legacy_pending"] = instance.duplicate(true)
        state["career_state"] = career_state
        if not SaveService.save_game(state):
            return {"ok": false, "reason": "save_failed"}
        return {"ok": true, "requires_slot_decision": true, "legacy": instance.duplicate(true)}

    slots.append(instance.duplicate(true))
    return _commit_selection(state, instance, slots, meta, "active")

static func replace_retirement_legacy(state: Dictionary, slot_index: int) -> Dictionary:
    if state.is_empty() or not bool(state.get("career", {}).get("finished", false)):
        return {"ok": false, "reason": "career_not_finished"}
    var career_state: Dictionary = state.get("career_state", {})
    if not career_state.get("retirement_legacy_selected", {}).is_empty():
        return {"ok": false, "reason": "already_selected"}
    var pending: Dictionary = career_state.get("retirement_legacy_pending", {})
    if pending.is_empty():
        return {"ok": false, "reason": "no_pending_legacy"}

    var meta: Dictionary = state.get("meta_state", {}).duplicate(true)
    var slots: Array = meta.get("legacy_slots", []).duplicate(true)
    if slot_index < 0 or slot_index >= slots.size():
        return {"ok": false, "reason": "invalid_slot"}

    var previous: Dictionary = slots[slot_index].duplicate(true)
    var replacement := pending.duplicate(true)
    slots[slot_index] = replacement
    _mark_history_legacy_replaced(meta, previous, replacement)
    var result := _commit_selection(state, replacement, slots, meta, "active")
    if bool(result.get("ok", false)):
        result["replaced"] = previous
        result["slot_index"] = slot_index
    return result

static func abandon_retirement_legacy(state: Dictionary) -> Dictionary:
    if state.is_empty() or not bool(state.get("career", {}).get("finished", false)):
        return {"ok": false, "reason": "career_not_finished"}
    var career_state: Dictionary = state.get("career_state", {})
    if not career_state.get("retirement_legacy_selected", {}).is_empty():
        return {"ok": false, "reason": "already_selected"}
    var pending: Dictionary = career_state.get("retirement_legacy_pending", {})
    if pending.is_empty():
        return {"ok": false, "reason": "no_pending_legacy"}

    var meta: Dictionary = state.get("meta_state", {}).duplicate(true)
    var slots: Array = meta.get("legacy_slots", []).duplicate(true)
    return _commit_selection(state, pending.duplicate(true), slots, meta, "abandoned")

static func pending_retirement_legacy(state: Dictionary) -> Dictionary:
    return state.get("career_state", {}).get("retirement_legacy_pending", {}).duplicate(true)

static func start_next_generation(game_state: Node) -> Dictionary:
    var state: Dictionary = game_state.state
    var career_state: Dictionary = state.get("career_state", {})
    var selected: Dictionary = career_state.get("retirement_legacy_selected", {})
    if selected.is_empty():
        return {"ok": false, "reason": "legacy_not_selected"}

    var meta: Dictionary = state.get("meta_state", {}).duplicate(true)
    var history: Array = meta.get("lineage_history", []).duplicate(true)
    if not bool(career_state.get("lineage_archived", false)):
        var career: Dictionary = state.get("career", {})
        var profile := retirement_profile(state)
        var legacy_status := str(selected.get("legacy_status", "active"))
        history.append({
            "generation": int(meta.get("generation", 1)),
            "boxer_name": str(state.get("boxer", {}).get("name", "무명 복서")),
            "wins": int(career.get("wins", 0)),
            "losses": int(career.get("losses", 0)),
            "draws": int(career.get("draws", 0)),
            "fights": int(career.get("fights", 0)),
            "ending": str(career.get("ending", "")),
            "career_high_points": int(profile.get("career_high_points", 0)),
            "career_high_rank": int(profile.get("career_high_rank", 50)),
            "legacy_definition_id": str(selected.get("definition_id", "")),
            "legacy_tier": str(profile.get("legacy_tier", "early_pro")),
            "flavor": str(profile.get("flavor", "")),
            "legacy_status": legacy_status,
            "legacy_active": legacy_status == "active",
        })
        career_state["lineage_archived"] = true
    meta["lineage_history"] = history
    meta["generation"] = int(meta.get("generation", 1)) + 1
    var world: Dictionary = state.get("world_state", {}).duplicate(true)

    game_state.new_career("무명 복서")
    game_state.state["meta_state"] = meta
    game_state.state["world_state"] = world
    game_state.state["first_launch_acknowledged"] = true
    game_state.state["weigh_in_acknowledged"] = true
    SaveService.save_game(game_state.state)
    return {"ok": true, "generation": int(meta.generation)}

static func effect_value(state: Dictionary, effect_key: String, context: Dictionary = {}) -> float:
    var meta: Dictionary = state.get("meta_state", {})
    var slots: Array = meta.get("legacy_slots", [])
    if slots.is_empty():
        return 0.0

    var counts: Dictionary = {}
    for value in slots:
        var instance: Dictionary = value
        var definition_id := str(instance.get("definition_id", ""))
        if definition_id.is_empty():
            continue
        counts[definition_id] = int(counts.get(definition_id, 0)) + 1

    var total := 0.0
    for definition_id in counts.keys():
        var definition := definition_by_id(str(definition_id))
        var effect: Dictionary = definition.get("effect", {})
        if not effect.has(effect_key):
            continue
        if not _context_allows(effect, context):
            continue
        var count := int(counts[definition_id])
        var base := float(effect.get(effect_key, 0.0))
        var stacking := str(definition.get("stacking", "additive"))
        var resolved := 0.0
        match stacking:
            "diminishing":
                var scale := 0.0
                for index in range(count):
                    scale += pow(DIMINISHING_FACTOR, index)
                resolved = base * scale
            "capped":
                resolved = base * float(count)
                if effect.has("cap"):
                    resolved = min(resolved, float(effect.get("cap", resolved)))
            _:
                resolved = base * float(count)
        total += resolved
    return total

static func apply_camp_growth_bonus(state: Dictionary, action: Dictionary) -> Dictionary:
    if str(action.get("kind", "training")) != "training":
        return {}
    var action_effects: Dictionary = action.get("effects", {})
    var context := {"camp_index": int(state.get("career", {}).get("fights", 0))}
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    var carry: Dictionary = career_state.get("legacy_growth_carry", {}).duplicate(true)
    var bonuses: Dictionary = {}

    for stat in TRAINABLE_STATS:
        var raw_gain := int(action_effects.get(stat, 0))
        if raw_gain <= 0:
            continue
        var percent := effect_value(state, "early_camp_growth_percent", context)
        if stat == "power":
            percent += effect_value(state, "training_power_percent", context)
        elif stat == "conditioning":
            percent += effect_value(state, "training_conditioning_percent", context)

        var fractional := float(carry.get(stat, 0.0)) + float(raw_gain) * percent / 100.0
        var percent_bonus := int(round(fractional))
        carry[stat] = fractional - float(percent_bonus)

        var flat_bonus := 0
        if stat == "technique":
            flat_bonus += int(round(effect_value(state, "training_technique_bonus", context)))
            if str(action.get("id", "")) == "mitts":
                flat_bonus += int(round(effect_value(state, "jab_training_bonus", context)))

        var requested_bonus: int = max(0, percent_bonus + flat_bonus)
        if requested_bonus <= 0:
            continue
        var before: int = int(state.get("boxer", {}).get(stat, 50))
        var after: int = int(clamp(before + requested_bonus, 1, 100))
        state.boxer[stat] = after
        var actual: int = after - before
        if actual > 0:
            bonuses[stat] = actual

    career_state["legacy_growth_carry"] = carry
    career_state["last_legacy_camp_bonus"] = bonuses.duplicate(true)
    state["career_state"] = career_state
    return bonuses

static func cycle_recovery_bonus(state: Dictionary) -> int:
    return max(0, int(round(effect_value(state, "cycle_recovery_bonus"))))

static func early_fight_fatigue_reduction(state: Dictionary, fight_index: int) -> int:
    return max(0, int(round(effect_value(state, "early_fatigue_reduction", {"fight_index": fight_index}))))

static func definitions() -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS_PATH))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

static func definition_by_id(definition_id: String) -> Dictionary:
    for definition in definitions():
        if str(definition.get("id", "")) == definition_id:
            return definition
    return {}

static func _build_instance(state: Dictionary, definition_id: String, meta: Dictionary) -> Dictionary:
    var profile := retirement_profile(state)
    var world_date: Dictionary = state.get("world_state", {}).get("world_date", {})
    return {
        "definition_id": definition_id,
        "source_boxer_name": str(state.get("boxer", {}).get("name", "무명 복서")),
        "source_generation": int(meta.get("generation", 1)),
        "source_retirement_year": int(world_date.get("year", 2030)),
        "source_ending": str(state.get("career", {}).get("ending", "")),
        "source_legacy_tier": str(profile.get("legacy_tier", "early_pro")),
        "source_flavor": str(profile.get("flavor", "")),
    }

static func _commit_selection(state: Dictionary, instance_value: Dictionary, slots: Array, meta_value: Dictionary, legacy_status: String) -> Dictionary:
    var instance := instance_value.duplicate(true)
    instance["legacy_status"] = legacy_status
    var meta := meta_value.duplicate(true)
    meta["legacy_slots"] = slots.duplicate(true)
    state["meta_state"] = meta
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["retirement_legacy_selected"] = instance.duplicate(true)
    career_state.erase("retirement_legacy_pending")
    state["career_state"] = career_state
    if not SaveService.save_game(state):
        return {"ok": false, "reason": "save_failed"}
    return {"ok": true, "legacy": instance.duplicate(true), "legacy_status": legacy_status}

static func _mark_history_legacy_replaced(meta: Dictionary, previous: Dictionary, replacement: Dictionary) -> void:
    var history: Array = meta.get("lineage_history", []).duplicate(true)
    for index in range(history.size()):
        var entry: Dictionary = history[index]
        if int(entry.get("generation", -1)) != int(previous.get("source_generation", -2)):
            continue
        if str(entry.get("legacy_definition_id", "")) != str(previous.get("definition_id", "")):
            continue
        if str(entry.get("boxer_name", "")) != str(previous.get("source_boxer_name", "")):
            continue
        entry["legacy_status"] = "replaced"
        entry["legacy_active"] = false
        entry["replaced_by_generation"] = int(replacement.get("source_generation", 0))
        entry["replaced_by_definition_id"] = str(replacement.get("definition_id", ""))
        history[index] = entry
        break
    meta["lineage_history"] = history

static func _context_allows(effect: Dictionary, context: Dictionary) -> bool:
    if effect.has("camp_limit"):
        if not context.has("camp_index") or int(context.get("camp_index", 0)) >= int(effect.get("camp_limit", 0)):
            return false
    if effect.has("fight_limit"):
        if not context.has("fight_index") or int(context.get("fight_index", 0)) >= int(effect.get("fight_limit", 0)):
            return false
    if effect.has("requires_read"):
        if not context.has("read") or float(context.get("read", 0.0)) < float(effect.get("requires_read", 0.0)):
            return false
    return true

static func _definitions_for_ids(ids: Array) -> Array:
    var result: Array = []
    for legacy_id in ids:
        var definition := definition_by_id(str(legacy_id))
        if not definition.is_empty():
            result.append(definition)
    return result

static func _retirement_flavor(state: Dictionary) -> String:
    var ending := str(state.get("career", {}).get("ending", ""))
    match ending:
        "health_retirement": return "망가진 몸이 남긴 교훈"
        "loss_retirement": return "패배에서 건진 해답"
        "bankrupt": return "가난한 링의 생존법"
        "age_retirement": return "노장의 생존법"
        "fight_limit": return "긴 커리어의 운영법"
        "world_champion": return "왕좌의 경험"
    var injury: Dictionary = state.get("boxer", {}).get("injury", {})
    if not injury.is_empty():
        return "부상을 견딘 복싱"
    return str(state.get("boxer", {}).get("identity_name", "한 복서의 방식"))
