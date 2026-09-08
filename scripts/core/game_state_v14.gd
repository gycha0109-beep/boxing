extends "res://scripts/core/game_state_v12.gd"

const WORLD_TITLE_MIN_FIGHTS := 16
const WORLD_TITLE_MIN_WINS := 12
const WORLD_TITLE_MIN_POINTS := 88
const LADDER_TITLE_KINDS := ["district", "regional", "national", "continental", "world_eliminator"]

const CAREER_STAGES := {
    "local_rookie": {"id":"local_rookie", "label":"동네 신인"},
    "district": {"id":"district", "label":"구·시 챔피언"},
    "regional": {"id":"regional", "label":"지역 챔피언"},
    "national": {"id":"national", "label":"대한민국 챔피언"},
    "continental": {"id":"continental", "label":"아시아 챔피언"},
    "world_ranked": {"id":"world_ranked", "label":"세계 랭커"},
    "world_contender": {"id":"world_contender", "label":"세계 타이틀 도전자"}
}

const TITLE_REQUIREMENTS := {
    "district": {"label":"구·시 챔피언 결정전", "min_fights":2, "min_wins":2},
    "regional": {"label":"지역 챔피언 결정전", "min_fights":5, "min_wins":4},
    "national": {"label":"대한민국 챔피언 결정전", "min_fights":8, "min_wins":6},
    "continental": {"label":"아시아 챔피언 결정전", "min_fights":11, "min_wins":8},
    "world_eliminator": {"label":"세계 타이틀 도전자 결정전", "min_fights":14, "min_wins":10},
    "world": {"label":"세계 챔피언 타이틀전", "min_fights":WORLD_TITLE_MIN_FIGHTS, "min_wins":WORLD_TITLE_MIN_WINS}
}

const STAT_HELP := {
    "power": "펀치 피해와 KO 위력",
    "speed": "선공과 적중에 유리",
    "technique": "공격 정확도와 피해 안정성",
    "defense": "피격과 KO 위험을 줄임",
    "conditioning": "체력 소모를 줄이고 후반을 버팀"
}

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["ladder_titles"] = []
    career_state.erase("last_ladder_title_won")
    state["career_state"] = career_state
    SaveService.save_game(state)

func begin_boxer_creation() -> void:
    if state.is_empty():
        return
    state["phase"] = "style_select"
    state["boxer_creation_complete"] = false
    state["talent_revealed"] = false
    SaveService.save_game(state)

func boxing_styles() -> Array:
    return fighter_identities.duplicate(true)

func select_boxing_style(identity_id: String) -> Dictionary:
    if str(state.get("phase", "")) != "style_select":
        return {"ok": false, "reason": "wrong_phase"}
    var selected: Dictionary = _identity_by_id(identity_id)
    if selected.is_empty():
        return {"ok": false, "reason": "unknown_style"}

    var boxer: Dictionary = state.get("boxer", {})
    var current: Dictionary = _identity_by_id(str(boxer.get("identity_id", "balanced")))
    var current_bonus: Dictionary = current.get("stat_bonus", {})
    var selected_bonus: Dictionary = selected.get("stat_bonus", {})
    for stat in TRAINABLE_STATS:
        var without_old := int(boxer.get(stat, 50)) - int(current_bonus.get(stat, 0))
        boxer[stat] = clamp(without_old + int(selected_bonus.get(stat, 0)), 1, 100)

    boxer["identity_id"] = str(selected.get("id", "balanced"))
    boxer["identity_name"] = str(selected.get("name", "균형형"))
    boxer["identity_description"] = str(selected.get("description", ""))
    boxer["identity_signature"] = str(selected.get("signature", ""))
    state["phase"] = "talent_reveal"
    state["talent_revealed"] = true
    SaveService.save_game(state)
    return {"ok": true, "style": selected.duplicate(true)}

func talent_definition() -> Dictionary:
    var trait_id := str(state.get("boxer", {}).get("trait_id", ""))
    for value in traits:
        var talent_data: Dictionary = value
        if str(talent_data.get("id", "")) == trait_id:
            return talent_data.duplicate(true)
    return {}

func confirm_talent() -> Dictionary:
    if str(state.get("phase", "")) != "talent_reveal":
        return {"ok": false, "reason": "wrong_phase"}
    state["boxer_creation_complete"] = true
    state["phase"] = "camp"
    SaveService.save_game(state)
    return {"ok": true}

func stat_help(stat_id: String) -> String:
    return str(STAT_HELP.get(stat_id, ""))

func ladder_titles() -> Array:
    var career_state: Dictionary = state.get("career_state", {})
    var values: Variant = career_state.get("ladder_titles", [])
    return values.duplicate(true) if typeof(values) == TYPE_ARRAY else []

func career_ladder_stage() -> Dictionary:
    var career: Dictionary = state.get("career", {})
    if _has_ladder_title("world_eliminator"):
        return CAREER_STAGES.world_contender.duplicate(true)
    if _has_ladder_title("continental"):
        if int(career.get("fights", 0)) >= 14 and int(career.get("wins", 0)) >= 10:
            return CAREER_STAGES.world_ranked.duplicate(true)
        return CAREER_STAGES.continental.duplicate(true)
    if _has_ladder_title("national"):
        return CAREER_STAGES.national.duplicate(true)
    if _has_ladder_title("regional"):
        return CAREER_STAGES.regional.duplicate(true)
    if _has_ladder_title("district"):
        return CAREER_STAGES.district.duplicate(true)
    return CAREER_STAGES.local_rookie.duplicate(true)

func career_ladder_next_stage() -> Dictionary:
    var next_kind := _next_required_title_kind()
    if next_kind.is_empty():
        return {}
    var requirement: Dictionary = TITLE_REQUIREMENTS.get(next_kind, {}).duplicate(true)
    requirement["id"] = next_kind
    requirement["title_kind"] = next_kind
    return requirement

func world_title_ready() -> bool:
    var career: Dictionary = state.get("career", {})
    return _has_ladder_title("world_eliminator") \
        and int(career.get("fights", 0)) >= WORLD_TITLE_MIN_FIGHTS \
        and int(career.get("wins", 0)) >= WORLD_TITLE_MIN_WINS \
        and int(career.get("career_points", 0)) >= WORLD_TITLE_MIN_POINTS

func get_fight_offers(all_opponents: Array) -> Array:
    var base_offers: Array = super.get_fight_offers(all_opponents)
    var result: Array = []

    var eligible_title := _eligible_ladder_title_kind()
    if not eligible_title.is_empty():
        var title_opponent := _opponent_for_title_kind(all_opponents, eligible_title)
        if not title_opponent.is_empty():
            result.append(title_opponent)
    elif world_title_ready():
        var world_champion := _opponent_for_title_kind(all_opponents, "world")
        if not world_champion.is_empty():
            result.append(world_champion)

    for value in base_offers:
        var opponent: Dictionary = value
        if bool(opponent.get("title_fight", false)):
            continue
        if not result.has(opponent):
            result.append(opponent)
        if result.size() >= 3:
            break

    if result.size() < 3:
        for value in all_opponents:
            var opponent: Dictionary = value
            if bool(opponent.get("title_fight", false)):
                continue
            if not result.has(opponent):
                result.append(opponent)
            if result.size() >= 3:
                break
    return result

func apply_fight_result(result: String, opponent: Dictionary, snapshot: Dictionary = {}) -> void:
    var title_kind := str(opponent.get("title_kind", ""))
    if title_kind in LADDER_TITLE_KINDS:
        var non_terminal_opponent: Dictionary = opponent.duplicate(true)
        non_terminal_opponent["title_fight"] = false
        super.apply_fight_result(result, non_terminal_opponent, snapshot)
        if result.begins_with("WIN"):
            _record_ladder_title(title_kind, opponent)
        return
    super.apply_fight_result(result, opponent, snapshot)

func start_next_generation() -> Dictionary:
    var result: Dictionary = super.start_next_generation()
    if bool(result.get("ok", false)):
        begin_boxer_creation()
    return result

func _has_ladder_title(title_kind: String) -> bool:
    return title_kind in ladder_titles()

func _next_required_title_kind() -> String:
    for title_kind in LADDER_TITLE_KINDS:
        if not _has_ladder_title(str(title_kind)):
            return str(title_kind)
    return "world"

func _eligible_ladder_title_kind() -> String:
    var next_kind := _next_required_title_kind()
    if next_kind.is_empty() or next_kind == "world":
        return ""
    var requirement: Dictionary = TITLE_REQUIREMENTS.get(next_kind, {})
    var career: Dictionary = state.get("career", {})
    if int(career.get("fights", 0)) < int(requirement.get("min_fights", 999)):
        return ""
    if int(career.get("wins", 0)) < int(requirement.get("min_wins", 999)):
        return ""
    return next_kind

func _opponent_for_title_kind(all_opponents: Array, title_kind: String) -> Dictionary:
    for value in all_opponents:
        var opponent: Dictionary = value
        if str(opponent.get("title_kind", "")) == title_kind:
            return opponent.duplicate(true)
    return {}

func _record_ladder_title(title_kind: String, opponent: Dictionary) -> void:
    var titles: Array = ladder_titles()
    if title_kind not in titles:
        titles.append(title_kind)
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["ladder_titles"] = titles
    career_state["last_ladder_title_won"] = title_kind
    state["career_state"] = career_state

    var summary: Dictionary = state.get("last_fight_summary", {}).duplicate(true)
    summary["title_won"] = title_kind
    summary["title_label"] = str(opponent.get("title_label", "TITLE"))
    state["last_fight_summary"] = summary
    SaveService.save_game(state)
