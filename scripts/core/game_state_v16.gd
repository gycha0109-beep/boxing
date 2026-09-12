extends "res://scripts/core/game_state_v15.gd"

const World = preload("res://scripts/core/world_state_service.gd")
const CareerRisk = preload("res://scripts/core/career_risk_service.gd")

func _ready() -> void:
    super._ready()
    CareerRisk.ensure_state(state)
    World.ensure_world(state)
    var career_state: Dictionary = state.get("career_state", {})
    if not career_state.has("career_start_age_months"):
        World.mark_career_start(state)
    SaveService.save_game(state)

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
    CareerRisk.ensure_state(state)
    World.ensure_world(state)
    World.mark_career_start(state)
    SaveService.save_game(state)

func get_fight_offers(all_opponents: Array) -> Array:
    World.ensure_world(state, all_opponents)
    var base_offers: Array = super.get_fight_offers(all_opponents)
    var offers: Array = []
    var current_champion: Dictionary = World.current_champion_definition(state, all_opponents)
    for value in base_offers:
        var opponent: Dictionary = value
        if str(opponent.get("title_kind", "")) == "world" and not current_champion.is_empty():
            if not _offer_has_id(offers, str(current_champion.get("id", ""))):
                offers.append(current_champion.duplicate(true))
            continue
        var decorated: Dictionary = World.decorate_opponent(state, opponent)
        if not bool(decorated.get("retired", false)) and not _offer_has_id(offers, str(decorated.get("id", ""))):
            offers.append(decorated)
    return offers

func select_opponent(opponent: Dictionary) -> void:
    super.select_opponent(World.decorate_opponent(state, opponent))

func apply_camp_action(action: Dictionary) -> Dictionary:
    var before_health: int = int(state.get("boxer", {}).get("health", 100))
    var before_fatigue: int = int(state.get("boxer", {}).get("fatigue", 0))
    var result: Dictionary = super.apply_camp_action(action)
    if bool(result.get("ok", false)):
        CareerRisk.apply_recovery_limits(state, before_health, before_fatigue)
        SaveService.save_game(state)
    return result

func apply_fight_result(result: String, opponent: Dictionary, snapshot: Dictionary = {}) -> void:
    var title_kind: String = str(opponent.get("title_kind", ""))
    super.apply_fight_result(result, opponent, snapshot)
    var damage_report: Dictionary = CareerRisk.apply_fight_damage(state, result, snapshot)
    var summary: Dictionary = state.get("last_fight_summary", {}).duplicate(true)
    summary["career_damage"] = int(damage_report.get("after", CareerRisk.career_damage(state)))
    summary["career_damage_delta"] = int(damage_report.get("delta", 0))
    summary["new_chronic_injuries"] = damage_report.get("new_chronic_injuries", []).duplicate(true)
    state["last_fight_summary"] = summary
    if title_kind == "world" and result.begins_with("WIN"):
        var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
        career_state["pending_world_title_win"] = {"id":str(opponent.get("id", "")), "name":str(opponent.get("name", ""))}
        state["career_state"] = career_state
    _check_retirement()
    if bool(state.get("career", {}).get("finished", false)):
        state["phase"] = "career_summary"
    SaveService.save_game(state)

func _begin_next_cycle() -> void:
    var before_health: int = int(state.get("boxer", {}).get("health", 100))
    var before_fatigue: int = int(state.get("boxer", {}).get("fatigue", 0))
    super._begin_next_cycle()
    CareerRisk.apply_recovery_limits(state, before_health, before_fatigue)
    SaveService.save_game(state)

func _check_retirement() -> void:
    super._check_retirement()
    if bool(state.get("career", {}).get("finished", false)):
        return
    if CareerRisk.forced_retirement_reached(state):
        state.career.finished = true
        state.career.ending = "career_damage_retirement"

func ending_text() -> String:
    if str(state.get("career", {}).get("ending", "")) == "career_damage_retirement":
        return "누적된 커리어 손상이 한계를 넘어 더는 선수 생활을 이어갈 수 없습니다."
    return super.ending_text()

func start_next_generation() -> Dictionary:
    CareerRisk.ensure_state(state)
    World.ensure_world(state)
    var elapsed_months: int = World.elapsed_career_months(state)
    var world_result: Dictionary = World.advance_world(state, elapsed_months)
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    var pending_title: Dictionary = career_state.get("pending_world_title_win", {}).duplicate(true)
    if not pending_title.is_empty():
        World.record_player_title_win(state, pending_title)
        World.advance_world(state, 0)
        career_state = state.get("career_state", {}).duplicate(true)
        career_state.erase("pending_world_title_win")
        state["career_state"] = career_state
    SaveService.save_game(state)
    var result: Dictionary = super.start_next_generation()
    if not bool(result.get("ok", false)):
        return result
    CareerRisk.ensure_state(state)
    World.ensure_world(state)
    World.mark_career_start(state)
    result["world_advanced_months"] = elapsed_months
    result["world_date"] = state.get("world_state", {}).get("world_date", {}).duplicate(true)
    result["champion_boxer_id"] = str(state.get("world_state", {}).get("champion_boxer_id", world_result.get("champion_boxer_id", "")))
    SaveService.save_game(state)
    return result

func world_opponent_definition(opponent: Dictionary) -> Dictionary:
    return World.decorate_opponent(state, opponent)

func world_champion_definition(all_opponents: Array = []) -> Dictionary:
    return World.current_champion_definition(state, all_opponents)

func world_summary() -> Dictionary:
    return World.world_summary(state)

func career_damage_value() -> int:
    return CareerRisk.career_damage(state)

func chronic_injuries() -> Array:
    return CareerRisk.chronic_injuries(state)

func career_health_ceiling() -> int:
    return CareerRisk.health_ceiling(state)

func career_recovery_penalty() -> int:
    return CareerRisk.recovery_penalty(state)

func _offer_has_id(offers: Array, opponent_id: String) -> bool:
    for value in offers:
        var opponent: Dictionary = value
        if str(opponent.get("id", "")) == opponent_id:
            return true
    return false
