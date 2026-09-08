extends "res://scripts/core/game_state.gd"

const Legacy = preload("res://scripts/core/legacy_service.gd")

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
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
