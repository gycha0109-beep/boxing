extends "res://scripts/core/game_state.gd"

const Legacy = preload("res://scripts/core/legacy_service.gd")

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
    Legacy.observe_career_peak(state)
    SaveService.save_game(state)

func apply_fight_result(result: String, opponent: Dictionary, snapshot: Dictionary = {}) -> void:
    super.apply_fight_result(result, opponent, snapshot)
    Legacy.observe_career_peak(state)
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

func start_next_generation() -> Dictionary:
    return Legacy.start_next_generation(self)

func legacy_definition(definition_id: String) -> Dictionary:
    return Legacy.definition_by_id(definition_id)
