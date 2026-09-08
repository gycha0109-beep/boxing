class_name LegacyService
extends RefCounted

const DEFINITIONS_PATH := "res://data/legacy_definitions.json"
const MAX_CANDIDATES := 3

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

    var candidates := prepare_retirement_candidates(state)
    var candidate_ids: Array[String] = []
    for candidate in candidates:
        candidate_ids.append(str(candidate.get("id", "")))
    if definition_id not in candidate_ids:
        return {"ok": false, "reason": "not_a_candidate"}

    var meta: Dictionary = state.get("meta_state", {})
    var slots: Array = meta.get("legacy_slots", [])
    var capacity := int(meta.get("legacy_capacity", 3))
    if slots.size() >= capacity:
        return {"ok": false, "reason": "legacy_slots_full"}

    var profile := retirement_profile(state)
    var world_date: Dictionary = state.get("world_state", {}).get("world_date", {})
    var instance := {
        "definition_id": definition_id,
        "source_boxer_name": str(state.get("boxer", {}).get("name", "무명 복서")),
        "source_generation": int(meta.get("generation", 1)),
        "source_retirement_year": int(world_date.get("year", 2030)),
        "source_ending": str(state.get("career", {}).get("ending", "")),
        "source_legacy_tier": str(profile.get("legacy_tier", "early_pro")),
        "source_flavor": str(profile.get("flavor", "")),
    }
    slots.append(instance)
    meta["legacy_slots"] = slots
    state["meta_state"] = meta
    career_state = state.get("career_state", {})
    career_state["retirement_legacy_selected"] = instance.duplicate(true)
    state["career_state"] = career_state
    if not SaveService.save_game(state):
        return {"ok": false, "reason": "save_failed"}
    return {"ok": true, "legacy": instance.duplicate(true)}

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

static func definitions() -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS_PATH))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

static func definition_by_id(definition_id: String) -> Dictionary:
    for definition in definitions():
        if str(definition.get("id", "")) == definition_id:
            return definition
    return {}

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
