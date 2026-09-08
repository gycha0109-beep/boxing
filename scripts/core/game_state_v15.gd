extends "res://scripts/core/game_state_v14.gd"

const STARTING_BASE_STAT := 40
const EQUIPMENT_PATH := "res://data/equipment.json"
const EQUIPMENT_SECTIONS := ["personal", "gym"]

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
    _rebase_starting_stats()
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["equipment_state"] = {
        "personal": {},
        "gym": {},
        "growth_carry": {},
        "total_spent": 0
    }
    state["career_state"] = career_state
    SaveService.save_game(state)

func equipment_catalog(section: String = "") -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EQUIPMENT_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return []
    if section.is_empty():
        var merged: Array = []
        for section_id in EQUIPMENT_SECTIONS:
            var values: Variant = parsed.get(section_id, [])
            if typeof(values) == TYPE_ARRAY:
                for value in values:
                    var item: Dictionary = value
                    var copy := item.duplicate(true)
                    copy["section"] = section_id
                    merged.append(copy)
        return merged
    var values: Variant = parsed.get(section, [])
    if typeof(values) != TYPE_ARRAY:
        return []
    var result: Array = []
    for value in values:
        var item: Dictionary = value
        var copy := item.duplicate(true)
        copy["section"] = section
        result.append(copy)
    return result

func equipment_slots(section: String) -> Array[String]:
    var slots: Array[String] = []
    for value in equipment_catalog(section):
        var item: Dictionary = value
        var slot := str(item.get("slot", ""))
        if not slot.is_empty() and slot not in slots:
            slots.append(slot)
    return slots

func equipment_definition(item_id: String) -> Dictionary:
    for value in equipment_catalog():
        var item: Dictionary = value
        if str(item.get("id", "")) == item_id:
            return item.duplicate(true)
    return {}

func current_equipment(section: String, slot: String) -> Dictionary:
    var equipment_state := _equipment_state()
    var section_state: Dictionary = equipment_state.get(section, {})
    var item_id := str(section_state.get(slot, ""))
    return equipment_definition(item_id) if not item_id.is_empty() else {}

func next_equipment_upgrade(section: String, slot: String) -> Dictionary:
    var current := current_equipment(section, slot)
    var current_tier := int(current.get("tier", 0))
    var candidate: Dictionary = {}
    for value in equipment_catalog(section):
        var item: Dictionary = value
        if str(item.get("slot", "")) != slot:
            continue
        if int(item.get("tier", 0)) == current_tier + 1:
            candidate = item.duplicate(true)
            break
    return candidate

func equipment_unlock_label(item: Dictionary) -> String:
    var required := str(item.get("required_title", ""))
    match required:
        "regional": return "지역 챔피언 이후"
        "continental": return "아시아 챔피언 이후"
        _: return "지금 구매 가능"

func can_purchase_equipment(section: String, item_id: String) -> Dictionary:
    if str(state.get("phase", "")) not in ["camp", "equipment_shop"]:
        return {"ok": false, "reason": "wrong_phase"}
    if section not in EQUIPMENT_SECTIONS:
        return {"ok": false, "reason": "unknown_section"}
    var item := equipment_definition(item_id)
    if item.is_empty() or str(item.get("section", "")) != section:
        return {"ok": false, "reason": "unknown_item"}

    var slot := str(item.get("slot", ""))
    var expected := next_equipment_upgrade(section, slot)
    if expected.is_empty() or str(expected.get("id", "")) != item_id:
        return {"ok": false, "reason": "not_next_upgrade"}

    var required := str(item.get("required_title", ""))
    if not required.is_empty() and not _has_ladder_title(required):
        return {"ok": false, "reason": "locked", "unlock": equipment_unlock_label(item)}

    var price := int(item.get("price", 0))
    if int(state.get("career", {}).get("money", 0)) < price:
        return {"ok": false, "reason": "money"}
    return {"ok": true}

func purchase_equipment(section: String, item_id: String) -> Dictionary:
    var allowed := can_purchase_equipment(section, item_id)
    if not bool(allowed.get("ok", false)):
        return allowed

    var item := equipment_definition(item_id)
    var slot := str(item.get("slot", ""))
    var previous := current_equipment(section, slot)
    var price := int(item.get("price", 0))
    state.career.money = int(state.career.money) - price

    if section == "personal":
        var previous_bonus: Dictionary = previous.get("stat_bonus", {})
        var next_bonus: Dictionary = item.get("stat_bonus", {})
        for stat in TRAINABLE_STATS:
            var delta := int(next_bonus.get(stat, 0)) - int(previous_bonus.get(stat, 0))
            if delta != 0:
                state.boxer[stat] = clamp(int(state.boxer.get(stat, STARTING_BASE_STAT)) + delta, 1, 100)

    var equipment_state := _equipment_state()
    var section_state: Dictionary = equipment_state.get(section, {}).duplicate(true)
    section_state[slot] = item_id
    equipment_state[section] = section_state
    equipment_state["total_spent"] = int(equipment_state.get("total_spent", 0)) + price
    _store_equipment_state(equipment_state)
    SaveService.save_game(state)
    return {"ok": true, "item": item.duplicate(true), "previous": previous.duplicate(true), "money": int(state.career.money)}

func apply_camp_action(action: Dictionary) -> Dictionary:
    var result: Dictionary = super.apply_camp_action(action)
    if not bool(result.get("ok", false)):
        return result
    if str(action.get("kind", "training")) != "training":
        return result

    var percent := gym_training_percent(str(action.get("id", "")))
    if percent <= 0.0:
        return result

    var equipment_state := _equipment_state()
    var carry: Dictionary = equipment_state.get("growth_carry", {}).duplicate(true)
    var bonuses: Dictionary = {}
    var effects: Dictionary = action.get("effects", {})
    var action_id := str(action.get("id", ""))
    for stat in TRAINABLE_STATS:
        var raw_gain := int(effects.get(stat, 0))
        if raw_gain <= 0:
            continue
        var carry_key := "%s:%s" % [action_id, stat]
        var fractional := float(carry.get(carry_key, 0.0)) + float(raw_gain) * percent / 100.0
        var bonus := int(floor(fractional + 0.000001))
        carry[carry_key] = fractional - float(bonus)
        if bonus <= 0:
            continue
        var before := int(state.boxer.get(stat, STARTING_BASE_STAT))
        var after := int(clamp(before + bonus, 1, 100))
        state.boxer[stat] = after
        if after > before:
            bonuses[stat] = after - before

    equipment_state["growth_carry"] = carry
    _store_equipment_state(equipment_state)
    if not bonuses.is_empty():
        result["equipment_growth_bonus"] = bonuses.duplicate(true)
    SaveService.save_game(state)
    return result

func gym_training_percent(action_id: String) -> float:
    var best := 0.0
    for slot in equipment_slots("gym"):
        var item := current_equipment("gym", slot)
        if item.is_empty():
            continue
        var actions: Array = item.get("action_ids", [])
        if action_id in actions:
            best = max(best, float(item.get("training_percent", 0.0)))
    return best

func equipment_total_spent() -> int:
    return int(_equipment_state().get("total_spent", 0))

func _rebase_starting_stats() -> void:
    var boxer: Dictionary = state.get("boxer", {})
    var trait_data := talent_definition()
    var identity := _identity_by_id(str(boxer.get("identity_id", "balanced")))
    var trait_bonus: Dictionary = trait_data.get("stat_bonus", {})
    var identity_bonus: Dictionary = identity.get("stat_bonus", {})
    for stat in TRAINABLE_STATS:
        boxer[stat] = clamp(STARTING_BASE_STAT + int(trait_bonus.get(stat, 0)) + int(identity_bonus.get(stat, 0)), 1, 100)

func _equipment_state() -> Dictionary:
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    var equipment_state: Dictionary = {}
    if typeof(career_state.get("equipment_state", {})) == TYPE_DICTIONARY:
        equipment_state = career_state.get("equipment_state", {}).duplicate(true)
    if not equipment_state.has("personal") or typeof(equipment_state.get("personal")) != TYPE_DICTIONARY:
        equipment_state["personal"] = {}
    if not equipment_state.has("gym") or typeof(equipment_state.get("gym")) != TYPE_DICTIONARY:
        equipment_state["gym"] = {}
    if not equipment_state.has("growth_carry") or typeof(equipment_state.get("growth_carry")) != TYPE_DICTIONARY:
        equipment_state["growth_carry"] = {}
    equipment_state["total_spent"] = int(equipment_state.get("total_spent", 0))
    return equipment_state

func _store_equipment_state(equipment_state: Dictionary) -> void:
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["equipment_state"] = equipment_state.duplicate(true)
    state["career_state"] = career_state
