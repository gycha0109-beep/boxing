class_name WorldStateService
extends RefCounted

const OPPONENTS_PATH := "res://data/opponents.json"
const WORLD_ROSTER_PATH := "res://data/world_roster.json"
const DEFAULT_WORLD_YEAR := 2030
const CHAMPION_RETIRE_AGE := 38
const GENERAL_RETIRE_AGE := 40
const DEFENSE_INTERVAL_MONTHS := 8

static func ensure_world(state: Dictionary, all_opponents: Array = []) -> void:
    if state.is_empty():
        return
    var world: Dictionary = {}
    if typeof(state.get("world_state", {})) == TYPE_DICTIONARY:
        world = state.get("world_state", {}).duplicate(true)
    var world_date: Dictionary = {}
    if typeof(world.get("world_date", {})) == TYPE_DICTIONARY:
        world_date = world.get("world_date", {}).duplicate(true)
    world_date["year"] = int(world_date.get("year", DEFAULT_WORLD_YEAR))
    world_date["month"] = clamp(int(world_date.get("month", 1)), 1, 12)
    world["world_date"] = world_date
    if not world.has("world_history") or typeof(world.get("world_history")) != TYPE_ARRAY:
        world["world_history"] = []
    if not world.has("title_history") or typeof(world.get("title_history")) != TYPE_ARRAY:
        world["title_history"] = []
    if not world.has("gyms") or typeof(world.get("gyms")) != TYPE_ARRAY:
        world["gyms"] = []
    world["world_seed"] = int(world.get("world_seed", 130013))
    var opponents: Array = world.get("opponents", []) if typeof(world.get("opponents", [])) == TYPE_ARRAY else []
    if opponents.is_empty():
        opponents = _seed_opponents(all_opponents)
        world["opponents"] = opponents
    else:
        world["opponents"] = _normalize_opponents(opponents)
    var champion_id: String = str(world.get("champion_boxer_id", ""))
    if champion_id.is_empty():
        champion_id = _seed_champion_id(world.get("opponents", []))
    world["champion_boxer_id"] = champion_id
    _sync_champion_flags(world)
    state["world_state"] = world

static func mark_career_start(state: Dictionary) -> void:
    ensure_world(state)
    var career_state: Dictionary = state.get("career_state", {}).duplicate(true)
    career_state["career_start_age_months"] = int(state.get("career", {}).get("age_months", 19 * 12))
    career_state["career_start_world_month"] = _world_total_months(state.get("world_state", {}).get("world_date", {}))
    state["career_state"] = career_state

static func elapsed_career_months(state: Dictionary) -> int:
    var career_state: Dictionary = state.get("career_state", {})
    var start_age: int = int(career_state.get("career_start_age_months", state.get("career", {}).get("age_months", 19 * 12)))
    var current_age: int = int(state.get("career", {}).get("age_months", start_age))
    return max(0, current_age - start_age)

static func advance_world(state: Dictionary, elapsed_months: int, all_opponents: Array = []) -> Dictionary:
    ensure_world(state, all_opponents)
    var world: Dictionary = state.get("world_state", {}).duplicate(true)
    var before_date: Dictionary = world.get("world_date", {}).duplicate(true)
    var months: int = max(0, elapsed_months)
    world["world_date"] = _date_from_total_months(_world_total_months(before_date) + months)
    var snapshots: Array = world.get("opponents", []).duplicate(true)
    for index in range(snapshots.size()):
        var snapshot: Dictionary = snapshots[index].duplicate(true)
        var age_months: int = int(snapshot.get("age_months", int(snapshot.get("age", 20)) * 12)) + months
        snapshot["age_months"] = age_months
        snapshot["age"] = int(age_months / 12)
        if not bool(snapshot.get("champion", false)) and int(snapshot.get("age", 0)) >= GENERAL_RETIRE_AGE:
            snapshot["retired"] = true
        snapshots[index] = snapshot
    world["opponents"] = snapshots
    var champion_id: String = str(world.get("champion_boxer_id", ""))
    if champion_id.begins_with("player_generation_"):
        _append_world_event(world, "player_champion_retired", {"champion_id": champion_id})
        world["champion_boxer_id"] = ""
        _select_successor(world, champion_id)
    else:
        var champion_index: int = _snapshot_index(world.get("opponents", []), champion_id)
        if champion_index >= 0:
            var champion: Dictionary = world.opponents[champion_index].duplicate(true)
            var defenses: int = int(floor(float(months) / float(DEFENSE_INTERVAL_MONTHS)))
            if defenses > 0:
                champion["title_defenses"] = int(champion.get("title_defenses", 0)) + defenses
                var record: Dictionary = champion.get("record", {}).duplicate(true)
                record["wins"] = int(record.get("wins", 0)) + defenses
                champion["record"] = record
                champion["career_damage"] = int(champion.get("career_damage", 0)) + defenses * 2
            var retire: bool = int(champion.get("age", 0)) >= CHAMPION_RETIRE_AGE or int(champion.get("career_damage", 0)) >= 100
            if retire:
                champion["retired"] = true
                champion["champion"] = false
                world.opponents[champion_index] = champion
                _append_world_event(world, "champion_retired", {"boxer_id": champion_id, "name": str(champion.get("name", champion_id)), "age": int(champion.get("age", 0)), "title_defenses": int(champion.get("title_defenses", 0))})
                world["champion_boxer_id"] = ""
                _select_successor(world, champion_id)
            else:
                world.opponents[champion_index] = champion
    _sync_champion_flags(world)
    _append_world_event(world, "world_advanced", {"months": months, "from": _date_label(before_date), "to": _date_label(world.get("world_date", {}))})
    state["world_state"] = world
    return {"elapsed_months": months, "world_date": world.get("world_date", {}).duplicate(true), "champion_boxer_id": str(world.get("champion_boxer_id", ""))}

static func record_player_title_win(state: Dictionary, defeated_opponent: Dictionary) -> void:
    ensure_world(state)
    var world: Dictionary = state.get("world_state", {}).duplicate(true)
    var previous_id: String = str(world.get("champion_boxer_id", ""))
    var previous_index: int = _snapshot_index(world.get("opponents", []), previous_id)
    if previous_index >= 0:
        var previous: Dictionary = world.opponents[previous_index].duplicate(true)
        previous["champion"] = false
        world.opponents[previous_index] = previous
    var generation: int = int(state.get("meta_state", {}).get("generation", 1))
    var player_id: String = "player_generation_%d" % generation
    world["champion_boxer_id"] = player_id
    var event: Dictionary = {"type":"player_world_title","year":int(world.get("world_date", {}).get("year", DEFAULT_WORLD_YEAR)),"month":int(world.get("world_date", {}).get("month", 1)),"champion_id":player_id,"name":str(state.get("boxer", {}).get("name", "무명 복서")),"defeated_id":str(defeated_opponent.get("id", previous_id)),"generation":generation}
    var title_history: Array = world.get("title_history", []).duplicate(true)
    title_history.append(event.duplicate(true))
    world["title_history"] = title_history
    var history: Array = world.get("world_history", []).duplicate(true)
    history.append(event)
    world["world_history"] = history
    _sync_champion_flags(world)
    state["world_state"] = world

static func decorate_opponent(state: Dictionary, opponent: Dictionary) -> Dictionary:
    if opponent.is_empty():
        return {}
    ensure_world(state)
    var result: Dictionary = opponent.duplicate(true)
    var snapshot: Dictionary = _snapshot_by_id(state.get("world_state", {}).get("opponents", []), str(opponent.get("id", "")))
    if snapshot.is_empty():
        return result
    for key in ["age", "age_months", "gym_id", "record", "title_defenses", "career_damage", "career_start_year", "traits", "retired", "champion"]:
        if snapshot.has(key):
            result[key] = snapshot[key].duplicate(true) if typeof(snapshot[key]) in [TYPE_DICTIONARY, TYPE_ARRAY] else snapshot[key]
    if bool(snapshot.get("champion", false)):
        var stats: Dictionary = result.get("stats", {}).duplicate(true)
        _apply_champion_age_profile(stats, int(snapshot.get("age", 0)))
        result["stats"] = stats
        result["world_age_profile"] = _age_profile_id(int(snapshot.get("age", 0)))
    return result

static func current_champion_definition(state: Dictionary, all_opponents: Array = []) -> Dictionary:
    ensure_world(state, all_opponents)
    var champion_id: String = str(state.get("world_state", {}).get("champion_boxer_id", ""))
    if champion_id.is_empty() or champion_id.begins_with("player_generation_"):
        return {}
    var catalog: Array = all_opponents if not all_opponents.is_empty() else _opponent_catalog()
    for value in catalog:
        var opponent: Dictionary = value
        if str(opponent.get("id", "")) == champion_id:
            var decorated: Dictionary = decorate_opponent(state, opponent)
            decorated["title_fight"] = true
            decorated["title_kind"] = "world"
            decorated["title_label"] = "세계 챔피언 타이틀전"
            decorated["tier"] = "title"
            decorated["rank"] = 1
            return decorated
    return {}

static func world_summary(state: Dictionary) -> Dictionary:
    ensure_world(state)
    var world: Dictionary = state.get("world_state", {})
    var champion_id: String = str(world.get("champion_boxer_id", ""))
    var summary: Dictionary = {"year":int(world.get("world_date", {}).get("year", DEFAULT_WORLD_YEAR)),"month":int(world.get("world_date", {}).get("month", 1)),"champion_boxer_id":champion_id,"champion_name":"타이틀 공석","champion_age":0,"champion_record":{},"title_defenses":0,"gym_id":""}
    if champion_id.begins_with("player_generation_"):
        summary["champion_name"] = str(state.get("boxer", {}).get("name", "플레이어 챔피언"))
        summary["champion_age"] = int(state.get("career", {}).get("age_months", 0)) / 12
        summary["champion_record"] = {"wins":int(state.get("career", {}).get("wins", 0)),"losses":int(state.get("career", {}).get("losses", 0)),"draws":int(state.get("career", {}).get("draws", 0))}
        return summary
    var snapshot: Dictionary = _snapshot_by_id(world.get("opponents", []), champion_id)
    if not snapshot.is_empty():
        summary["champion_name"] = str(snapshot.get("name", champion_id))
        summary["champion_age"] = int(snapshot.get("age", 0))
        summary["champion_record"] = snapshot.get("record", {}).duplicate(true)
        summary["title_defenses"] = int(snapshot.get("title_defenses", 0))
        summary["gym_id"] = str(snapshot.get("gym_id", ""))
    return summary

static func _seed_opponents(all_opponents: Array) -> Array:
    var catalog: Array = all_opponents if not all_opponents.is_empty() else _opponent_catalog()
    var roster_meta: Dictionary = {}
    for value in _world_roster():
        var meta: Dictionary = value
        roster_meta[str(meta.get("id", ""))] = meta
    var snapshots: Array = []
    for value in catalog:
        var opponent: Dictionary = value
        var opponent_id: String = str(opponent.get("id", ""))
        var meta: Dictionary = roster_meta.get(opponent_id, {})
        var age: int = int(meta.get("age", 24))
        snapshots.append({"id":opponent_id,"name":str(opponent.get("name", opponent_id)),"age":age,"age_months":age*12,"style":str(opponent.get("style", "balanced")),"gym_id":str(meta.get("gym_id", "independent")),"record":meta.get("record", {"wins":0,"losses":0,"draws":0}).duplicate(true),"rank":int(opponent.get("rank", 50)),"champion":bool(meta.get("champion", false)),"title_defenses":int(meta.get("title_defenses", 0)),"career_damage":int(meta.get("career_damage", 0)),"career_start_year":int(meta.get("career_start_year", DEFAULT_WORLD_YEAR)),"traits":meta.get("traits", []).duplicate(true),"retired":false})
    return snapshots

static func _normalize_opponents(values: Array) -> Array:
    var result: Array = []
    for value in values:
        if typeof(value) != TYPE_DICTIONARY:
            continue
        var snapshot: Dictionary = value.duplicate(true)
        var age: int = int(snapshot.get("age", 24))
        snapshot["age_months"] = int(snapshot.get("age_months", age * 12))
        snapshot["age"] = int(snapshot.age_months / 12)
        if typeof(snapshot.get("record", {})) != TYPE_DICTIONARY:
            snapshot["record"] = {"wins":0,"losses":0,"draws":0}
        if typeof(snapshot.get("traits", [])) != TYPE_ARRAY:
            snapshot["traits"] = []
        snapshot["champion"] = bool(snapshot.get("champion", false))
        snapshot["retired"] = bool(snapshot.get("retired", false))
        snapshot["title_defenses"] = max(0, int(snapshot.get("title_defenses", 0)))
        snapshot["career_damage"] = max(0, int(snapshot.get("career_damage", 0)))
        result.append(snapshot)
    return result

static func _seed_champion_id(opponents: Array) -> String:
    for value in opponents:
        var snapshot: Dictionary = value
        if bool(snapshot.get("champion", false)):
            return str(snapshot.get("id", ""))
    return "viktor_kozlov"

static func _select_successor(world: Dictionary, excluded_id: String) -> void:
    var best_index: int = -1
    var best_rank: int = 999
    var catalog_by_id: Dictionary = {}
    for value in _opponent_catalog():
        var opponent: Dictionary = value
        catalog_by_id[str(opponent.get("id", ""))] = opponent
    var snapshots: Array = world.get("opponents", [])
    for index in range(snapshots.size()):
        var snapshot: Dictionary = snapshots[index]
        var opponent_id: String = str(snapshot.get("id", ""))
        if opponent_id == excluded_id or bool(snapshot.get("retired", false)):
            continue
        var base: Dictionary = catalog_by_id.get(opponent_id, {})
        var tier: String = str(base.get("tier", ""))
        if tier not in ["world", "title"]:
            continue
        var rank: int = int(snapshot.get("rank", base.get("rank", 50)))
        if rank < best_rank:
            best_rank = rank
            best_index = index
    if best_index < 0:
        return
    var successor: Dictionary = snapshots[best_index].duplicate(true)
    successor["champion"] = true
    successor["rank"] = 1
    successor["title_defenses"] = 0
    snapshots[best_index] = successor
    world["opponents"] = snapshots
    world["champion_boxer_id"] = str(successor.get("id", ""))
    var event: Dictionary = {"type":"new_world_champion","year":int(world.get("world_date", {}).get("year", DEFAULT_WORLD_YEAR)),"month":int(world.get("world_date", {}).get("month", 1)),"champion_id":str(successor.get("id", "")),"name":str(successor.get("name", ""))}
    var title_history: Array = world.get("title_history", []).duplicate(true)
    title_history.append(event.duplicate(true))
    world["title_history"] = title_history
    var history: Array = world.get("world_history", []).duplicate(true)
    history.append(event)
    world["world_history"] = history

static func _sync_champion_flags(world: Dictionary) -> void:
    var champion_id: String = str(world.get("champion_boxer_id", ""))
    var snapshots: Array = world.get("opponents", []).duplicate(true)
    for index in range(snapshots.size()):
        var snapshot: Dictionary = snapshots[index].duplicate(true)
        snapshot["champion"] = str(snapshot.get("id", "")) == champion_id and not bool(snapshot.get("retired", false))
        snapshots[index] = snapshot
    world["opponents"] = snapshots

static func _append_world_event(world: Dictionary, event_type: String, detail: Dictionary) -> void:
    var event: Dictionary = detail.duplicate(true)
    event["type"] = event_type
    event["year"] = int(world.get("world_date", {}).get("year", DEFAULT_WORLD_YEAR))
    event["month"] = int(world.get("world_date", {}).get("month", 1))
    var history: Array = world.get("world_history", []).duplicate(true)
    history.append(event)
    world["world_history"] = history

static func _apply_champion_age_profile(stats: Dictionary, age: int) -> void:
    var adjustments: Dictionary = {}
    if age < 27:
        adjustments = {"speed":2,"conditioning":2,"technique":-1}
    elif age <= 33:
        adjustments = {}
    elif age <= 35:
        adjustments = {"speed":-2,"conditioning":-2,"technique":1,"defense":1}
    else:
        adjustments = {"speed":-4,"conditioning":-3,"technique":2,"defense":2}
    for key in adjustments.keys():
        stats[key] = clamp(int(stats.get(key, 50)) + int(adjustments[key]), 1, 99)

static func _age_profile_id(age: int) -> String:
    if age < 27: return "young"
    if age <= 33: return "prime"
    if age <= 35: return "older"
    return "veteran"

static func _snapshot_by_id(values: Array, opponent_id: String) -> Dictionary:
    for value in values:
        var snapshot: Dictionary = value
        if str(snapshot.get("id", "")) == opponent_id:
            return snapshot.duplicate(true)
    return {}

static func _snapshot_index(values: Array, opponent_id: String) -> int:
    for index in range(values.size()):
        var snapshot: Dictionary = values[index]
        if str(snapshot.get("id", "")) == opponent_id:
            return index
    return -1

static func _world_total_months(date: Dictionary) -> int:
    var year: int = int(date.get("year", DEFAULT_WORLD_YEAR))
    var month: int = clamp(int(date.get("month", 1)), 1, 12)
    return year * 12 + month - 1

static func _date_from_total_months(total: int) -> Dictionary:
    return {"year":int(floor(float(total) / 12.0)), "month":posmod(total, 12) + 1}

static func _date_label(date: Dictionary) -> String:
    return "%04d-%02d" % [int(date.get("year", DEFAULT_WORLD_YEAR)), int(date.get("month", 1))]

static func _opponent_catalog() -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OPPONENTS_PATH))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

static func _world_roster() -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD_ROSTER_PATH))
    return parsed if typeof(parsed) == TYPE_ARRAY else []
