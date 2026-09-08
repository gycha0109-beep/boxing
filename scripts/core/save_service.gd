class_name SaveService
extends RefCounted

const SAVE_PATH := "user://career_v3.json"
const BACKUP_PATH := "user://career_v3.backup.json"
const PREVIOUS_SAVE_PATH := "user://career_v2.json"
const PREVIOUS_BACKUP_PATH := "user://career_v2.backup.json"
const SCHEMA_VERSION := 3
const PREVIOUS_SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const DEFAULT_WORLD_YEAR := 2030
const DEFAULT_LEGACY_CAPACITY := 3
const MAX_LEGACY_CAPACITY := 5

static func save_game(state: Dictionary) -> bool:
    _ensure_foundation(state)
    if not _validate_payload(state):
        return false

    var payload_text := JSON.stringify(state)
    var envelope := {"schema": SCHEMA_VERSION, "payload_text": payload_text, "checksum": _sha256(payload_text)}
    var text := JSON.stringify(envelope, "  ")

    # A corrupt primary must never replace the last known-good backup.
    if FileAccess.file_exists(SAVE_PATH) and not _load_from(SAVE_PATH).is_empty():
        var old := FileAccess.get_file_as_string(SAVE_PATH)
        var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
        if backup:
            backup.store_string(old)
            backup.close()

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(text)
    file.close()
    return true

static func load_game() -> Dictionary:
    var state := _load_from(SAVE_PATH)
    if not state.is_empty():
        return state
    state = _load_from(BACKUP_PATH)
    if not state.is_empty():
        return state
    state = _load_previous_v2()
    if not state.is_empty():
        return state
    return _load_legacy_v1()

static func _load_from(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    if int(parsed.get("schema", -1)) != SCHEMA_VERSION:
        return {}
    var payload_text := str(parsed.get("payload_text", ""))
    if payload_text.is_empty():
        return {}
    if str(parsed.get("checksum", "")) != _sha256(payload_text):
        return {}
    var payload = JSON.parse_string(payload_text)
    if typeof(payload) != TYPE_DICTIONARY:
        return {}
    if not _validate_payload(payload):
        return {}
    return payload

static func _load_previous_v2() -> Dictionary:
    for path in [PREVIOUS_SAVE_PATH, PREVIOUS_BACKUP_PATH]:
        if not FileAccess.file_exists(path):
            continue
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
        if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema", -1)) != PREVIOUS_SCHEMA_VERSION:
            continue
        var payload_text := str(parsed.get("payload_text", ""))
        if payload_text.is_empty() or str(parsed.get("checksum", "")) != _sha256(payload_text):
            continue
        var payload = JSON.parse_string(payload_text)
        if typeof(payload) != TYPE_DICTIONARY or not _validate_runtime_payload(payload):
            continue
        var migrated: Dictionary = _migrate_v2(payload)
        if _validate_payload(migrated):
            save_game(migrated)
            return migrated
    return {}

static func _load_legacy_v1() -> Dictionary:
    for path in ["user://career_v1.json", "user://career_v1.backup.json"]:
        if not FileAccess.file_exists(path):
            continue
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
        if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema", -1)) != LEGACY_SCHEMA_VERSION:
            continue
        var payload_text := str(parsed.get("payload_text", ""))
        if payload_text.is_empty() or str(parsed.get("checksum", "")) != _sha256(payload_text):
            continue
        var payload = JSON.parse_string(payload_text)
        if typeof(payload) != TYPE_DICTIONARY:
            continue
        var migrated := _migrate_v1(payload)
        if _validate_payload(migrated):
            save_game(migrated)
            return migrated
    return {}

static func _migrate_v2(old: Dictionary) -> Dictionary:
    var migrated: Dictionary = old.duplicate(true)
    _ensure_foundation(migrated)
    return migrated

static func _migrate_v1(old: Dictionary) -> Dictionary:
    var boxer: Dictionary = old.get("boxer", {}).duplicate(true)
    boxer["weight_kg"] = float(boxer.get("weight_kg", 61.8))
    boxer["trait_id"] = str(boxer.get("trait_id", "workhorse"))
    boxer["trait_name"] = str(boxer.get("trait_name", "훈련광"))
    boxer["modifiers"] = boxer.get("modifiers", {"training_fatigue_multiplier": 0.78}).duplicate(true)
    boxer["injury"] = boxer.get("injury", {}).duplicate(true)
    var old_career: Dictionary = old.get("career", {})
    var career := {
        "age_months": int(old_career.get("age", 19)) * 12,
        "money": int(old_career.get("money", 120000)),
        "reputation": int(old_career.get("reputation", 0)),
        "wins": int(old_career.get("wins", 0)), "losses": int(old_career.get("losses", 0)), "draws": int(old_career.get("draws", 0)), "fights": int(old_career.get("fights", 0)),
        "career_points": clamp(int(old_career.get("reputation", 0)) * 2, 0, 100),
        "tier": "prospect", "rank": int(old_career.get("rank", 50)), "champion": false, "finished": false, "ending": ""
    }
    var migrated := {"phase":"camp","boxer":boxer,"career":career,"last_camp_action":"","selected_opponent":"","last_result":"","last_fight_summary":{},"last_weigh_in":{},"pending_event":{},"fight_seed":0,"active_fight":{}}
    _ensure_foundation(migrated)
    return migrated

static func _ensure_foundation(payload: Dictionary) -> void:
    var meta: Dictionary = {}
    if typeof(payload.get("meta_state", {})) == TYPE_DICTIONARY:
        meta = payload.get("meta_state", {}).duplicate(true)
    meta["generation"] = max(1, int(meta.get("generation", 1)))
    meta["legacy_capacity"] = clamp(int(meta.get("legacy_capacity", DEFAULT_LEGACY_CAPACITY)), DEFAULT_LEGACY_CAPACITY, MAX_LEGACY_CAPACITY)
    if typeof(meta.get("legacy_slots", [])) != TYPE_ARRAY:
        meta["legacy_slots"] = []
    if typeof(meta.get("achievements", [])) != TYPE_ARRAY:
        meta["achievements"] = []
    if typeof(meta.get("lineage_history", [])) != TYPE_ARRAY:
        meta["lineage_history"] = []
    payload["meta_state"] = meta

    var world: Dictionary = {}
    if typeof(payload.get("world_state", {})) == TYPE_DICTIONARY:
        world = payload.get("world_state", {}).duplicate(true)
    var world_date: Dictionary = {}
    if typeof(world.get("world_date", {})) == TYPE_DICTIONARY:
        world_date = world.get("world_date", {}).duplicate(true)
    world_date["year"] = int(world_date.get("year", DEFAULT_WORLD_YEAR))
    world_date["month"] = clamp(int(world_date.get("month", 1)), 1, 12)
    world["world_date"] = world_date
    world["champion_boxer_id"] = str(world.get("champion_boxer_id", ""))
    if typeof(world.get("opponents", [])) != TYPE_ARRAY:
        world["opponents"] = []
    if typeof(world.get("gyms", [])) != TYPE_ARRAY:
        world["gyms"] = []
    if typeof(world.get("title_history", [])) != TYPE_ARRAY:
        world["title_history"] = []
    world["world_seed"] = int(world.get("world_seed", 0))
    payload["world_state"] = world

    var career_state: Dictionary = {}
    if typeof(payload.get("career_state", {})) == TYPE_DICTIONARY:
        career_state = payload.get("career_state", {}).duplicate(true)
    if typeof(career_state.get("injuries", [])) != TYPE_ARRAY:
        career_state["injuries"] = []
    career_state["career_damage"] = max(0, int(career_state.get("career_damage", 0)))
    if typeof(career_state.get("fight_history", [])) != TYPE_ARRAY:
        career_state["fight_history"] = []
    career_state["boxer"] = payload.get("boxer", {}).duplicate(true)
    career_state["rank"] = int(payload.get("career", {}).get("rank", 50))
    career_state["selected_game_plan"] = str(payload.get("selected_game_plan", ""))
    career_state["active_fight"] = payload.get("active_fight", {}).duplicate(true)
    payload["career_state"] = career_state

static func _validate_payload(payload: Dictionary) -> bool:
    if not _validate_runtime_payload(payload):
        return false
    for key in ["meta_state", "world_state", "career_state"]:
        if not payload.has(key) or typeof(payload.get(key)) != TYPE_DICTIONARY:
            return false

    var meta: Dictionary = payload.meta_state
    for key in ["generation", "legacy_capacity", "legacy_slots", "achievements", "lineage_history"]:
        if not meta.has(key):
            return false
    var generation: int = int(meta.generation)
    var capacity: int = int(meta.legacy_capacity)
    if generation < 1:
        return false
    if capacity < DEFAULT_LEGACY_CAPACITY or capacity > MAX_LEGACY_CAPACITY:
        return false
    if typeof(meta.legacy_slots) != TYPE_ARRAY or meta.legacy_slots.size() > capacity:
        return false
    if typeof(meta.achievements) != TYPE_ARRAY or typeof(meta.lineage_history) != TYPE_ARRAY:
        return false

    var world: Dictionary = payload.world_state
    for key in ["world_date", "champion_boxer_id", "opponents", "gyms", "title_history", "world_seed"]:
        if not world.has(key):
            return false
    if typeof(world.world_date) != TYPE_DICTIONARY:
        return false
    if int(world.world_date.get("month", 0)) < 1 or int(world.world_date.get("month", 0)) > 12:
        return false
    if typeof(world.opponents) != TYPE_ARRAY or typeof(world.gyms) != TYPE_ARRAY or typeof(world.title_history) != TYPE_ARRAY:
        return false

    var career_state: Dictionary = payload.career_state
    for key in ["boxer", "injuries", "career_damage", "rank", "fight_history", "selected_game_plan", "active_fight"]:
        if not career_state.has(key):
            return false
    if typeof(career_state.boxer) != TYPE_DICTIONARY or typeof(career_state.injuries) != TYPE_ARRAY or typeof(career_state.fight_history) != TYPE_ARRAY or typeof(career_state.active_fight) != TYPE_DICTIONARY:
        return false
    if int(career_state.career_damage) < 0:
        return false
    return true

static func _validate_runtime_payload(payload: Dictionary) -> bool:
    for key in ["boxer", "career", "phase"]:
        if not payload.has(key):
            return false
    var boxer = payload.get("boxer", {})
    for key in ["name","power","speed","technique","defense","conditioning","fatigue","health","weight_kg","trait_id","modifiers","injury"]:
        if not boxer.has(key):
            return false
    var career = payload.get("career", {})
    for key in ["age_months","money","reputation","wins","losses","draws","fights","career_points","tier","rank","champion","finished","ending"]:
        if not career.has(key):
            return false
    if int(boxer.health) < 0 or int(boxer.health) > 100:
        return false
    if int(boxer.fatigue) < 0 or int(boxer.fatigue) > 100:
        return false
    if int(career.career_points) < 0 or int(career.career_points) > 100:
        return false
    return true

static func _sha256(text: String) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(text.to_utf8_buffer())
    return context.finish().hex_encode()
