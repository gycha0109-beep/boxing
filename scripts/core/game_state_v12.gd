extends "res://scripts/core/game_state.gd"

const Legacy = preload("res://scripts/core/legacy_service.gd")
const PREPARATION_PATH := "res://data/fight_preparations.json"

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
    state["selected_tactical_prep"] = ""
    state["selected_condition_prep"] = ""
    state.erase("pre_condition_snapshot")
    Legacy.observe_career_peak(state)
    SaveService.save_game(state)

func apply_camp_action(action: Dictionary) -> Dictionary:
    var result: Dictionary = super.apply_camp_action(action)
    if not bool(result.get("ok", false)):
        return result
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    if str(action.get("kind", "training")) != "training":
        career_state["last_legacy_camp_bonus"] = {}
        state["career_state"] = career_state
    var bonuses := Legacy.apply_camp_growth_bonus(state, action)
    if not bonuses.is_empty():
        result["legacy_growth_bonus"] = bonuses.duplicate(true)
    SaveService.save_game(state)
    return result

func select_opponent(opponent: Dictionary) -> void:
    super.select_opponent(opponent)
    state["selected_tactical_prep"] = ""
    state["selected_condition_prep"] = ""
    state.erase("pre_condition_snapshot")
    state["phase"] = "tactical_prep"
    SaveService.save_game(state)

func tactical_preparations() -> Array:
    return _preparation_section("tactical")

func condition_preparations() -> Array:
    return _preparation_section("condition")

func preparation_definition(section: String, preparation_id: String) -> Dictionary:
    for value in _preparation_section(section):
        var definition: Dictionary = value
        if str(definition.get("id", "")) == preparation_id:
            return definition
    return {}

func select_tactical_preparation(preparation_id: String) -> Dictionary:
    if str(state.get("phase", "")) != "tactical_prep":
        return {"ok": false, "reason": "wrong_phase"}
    var definition := preparation_definition("tactical", preparation_id)
    if definition.is_empty():
        return {"ok": false, "reason": "unknown_preparation"}
    state["selected_tactical_prep"] = preparation_id
    state["phase"] = "condition_prep"
    SaveService.save_game(state)
    return {"ok": true, "preparation": definition}

func select_condition_preparation(preparation_id: String) -> Dictionary:
    if str(state.get("phase", "")) != "condition_prep":
        return {"ok": false, "reason": "wrong_phase"}
    var definition := preparation_definition("condition", preparation_id)
    if definition.is_empty():
        return {"ok": false, "reason": "unknown_preparation"}

    var boxer: Dictionary = state.get("boxer", {})
    state["pre_condition_snapshot"] = {
        "fatigue": int(boxer.get("fatigue", 0)),
        "health": int(boxer.get("health", 0)),
        "weight_kg": float(boxer.get("weight_kg", 0.0))
    }
    var immediate: Dictionary = definition.get("immediate", {})
    boxer["fatigue"] = clamp(int(boxer.get("fatigue", 0)) + int(immediate.get("fatigue", 0)), 0, 100)
    boxer["health"] = clamp(int(boxer.get("health", 0)) + int(immediate.get("health", 0)), 0, 100)
    boxer["weight_kg"] = clamp(float(boxer.get("weight_kg", 0.0)) + float(immediate.get("weight", 0.0)), 57.0, 68.0)
    state["selected_condition_prep"] = preparation_id
    state["phase"] = "game_plan"
    SaveService.save_game(state)
    return {"ok": true, "preparation": definition}

func return_to_condition_preparation() -> Dictionary:
    if str(state.get("phase", "")) != "game_plan":
        return {"ok": false, "reason": "wrong_phase"}
    _rollback_condition_preparation()
    state["selected_condition_prep"] = ""
    state["selected_game_plan"] = ""
    state["phase"] = "condition_prep"
    SaveService.save_game(state)
    return {"ok": true}

func return_to_tactical_preparation() -> Dictionary:
    if str(state.get("phase", "")) != "condition_prep":
        return {"ok": false, "reason": "wrong_phase"}
    state["selected_tactical_prep"] = ""
    state["phase"] = "tactical_prep"
    SaveService.save_game(state)
    return {"ok": true}

func return_to_fight_offers_from_preparation() -> Dictionary:
    if str(state.get("phase", "")) != "tactical_prep":
        return {"ok": false, "reason": "wrong_phase"}
    state["selected_opponent"] = ""
    state["selected_tactical_prep"] = ""
    state["selected_condition_prep"] = ""
    state.erase("pre_condition_snapshot")
    state["selected_game_plan"] = ""
    state["last_weigh_in"] = {}
    state["fight_seed"] = 0
    state["active_fight"] = {}
    state["phase"] = "fight_offer"
    SaveService.save_game(state)
    return {"ok": true}

func get_fight_boxer() -> Dictionary:
    var boxer: Dictionary = super.get_fight_boxer()
    var tactical := preparation_definition("tactical", str(state.get("selected_tactical_prep", "")))
    var condition := preparation_definition("condition", str(state.get("selected_condition_prep", "")))

    var condition_stats: Dictionary = condition.get("global_stats", {})
    for stat in TRAINABLE_STATS:
        if condition_stats.has(stat):
            boxer[stat] = clamp(int(boxer.get(stat, 50)) + int(condition_stats[stat]), 1, 100)

    var plan: Dictionary = boxer.get("game_plan", {}).duplicate(true)
    var merged_modifiers: Dictionary = plan.get("action_modifiers", {}).duplicate(true)
    var tactical_modifiers: Dictionary = tactical.get("action_modifiers", {})
    for action_value in tactical_modifiers.keys():
        var action_id := str(action_value)
        var merged: Dictionary = merged_modifiers.get(action_id, {}).duplicate(true)
        var prep_mods: Dictionary = tactical_modifiers[action_value]
        for key_value in prep_mods.keys():
            var key := str(key_value)
            if key in TRAINABLE_STATS:
                merged[key] = int(merged.get(key, 0)) + int(prep_mods[key_value])
        merged_modifiers[action_id] = merged
    plan["action_modifiers"] = merged_modifiers
    boxer["game_plan"] = plan
    boxer["tactical_preparation"] = tactical.duplicate(true)
    boxer["condition_preparation"] = condition.duplicate(true)
    return boxer

func apply_fight_result(result: String, opponent: Dictionary, snapshot: Dictionary = {}) -> void:
    var fight_index := int(state.get("career", {}).get("fights", 0))
    var fatigue_reduction := Legacy.early_fight_fatigue_reduction(state, fight_index)
    super.apply_fight_result(result, opponent, snapshot)
    if fatigue_reduction > 0:
        state.boxer.fatigue = max(0, int(state.boxer.get("fatigue", 0)) - fatigue_reduction)
        var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
        career_state["last_legacy_fight_fatigue_reduction"] = fatigue_reduction
        state["career_state"] = career_state
    Legacy.observe_career_peak(state)
    SaveService.save_game(state)

func _begin_next_cycle() -> void:
    var recovery_bonus := Legacy.cycle_recovery_bonus(state)
    state["selected_tactical_prep"] = ""
    state["selected_condition_prep"] = ""
    state.erase("pre_condition_snapshot")
    super._begin_next_cycle()
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    if recovery_bonus > 0:
        state.boxer.fatigue = max(0, int(state.boxer.get("fatigue", 0)) - recovery_bonus)
        career_state["last_legacy_cycle_recovery"] = recovery_bonus
    else:
        career_state.erase("last_legacy_cycle_recovery")
    state["career_state"] = career_state
    SaveService.save_game(state)

func _sync_progression() -> void:
    super._sync_progression()
    Legacy.observe_career_peak(state)

func retirement_legacy_profile() -> Dictionary:
    return Legacy.retirement_profile(state)

func retirement_legacy_candidates() -> Array:
    return Legacy.prepare_retirement_candidates(state)

func select_retirement_legacy(definition_id: String) -> Dictionary:
    return Legacy.select_retirement_legacy(state, definition_id)

func pending_retirement_legacy() -> Dictionary:
    return Legacy.pending_retirement_legacy(state)

func replace_retirement_legacy(slot_index: int) -> Dictionary:
    return Legacy.replace_retirement_legacy(state, slot_index)

func abandon_retirement_legacy() -> Dictionary:
    return Legacy.abandon_retirement_legacy(state)

func start_next_generation() -> Dictionary:
    return Legacy.start_next_generation(self)

func legacy_definition(definition_id: String) -> Dictionary:
    return Legacy.definition_by_id(definition_id)

func legacy_effect_value(effect_key: String, context: Dictionary = {}) -> float:
    return Legacy.effect_value(state, effect_key, context)

func _preparation_section(section: String) -> Array:
    var file := FileAccess.open(PREPARATION_PATH, FileAccess.READ)
    if file == null:
        return []
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return []
    var values: Variant = parsed.get(section, [])
    return values if typeof(values) == TYPE_ARRAY else []

func _rollback_condition_preparation() -> void:
    var snapshot: Dictionary = state.get("pre_condition_snapshot", {})
    if snapshot.is_empty():
        return
    var boxer: Dictionary = state.get("boxer", {})
    boxer["fatigue"] = int(snapshot.get("fatigue", boxer.get("fatigue", 0)))
    boxer["health"] = int(snapshot.get("health", boxer.get("health", 0)))
    boxer["weight_kg"] = float(snapshot.get("weight_kg", boxer.get("weight_kg", 0.0)))
    state.erase("pre_condition_snapshot")
