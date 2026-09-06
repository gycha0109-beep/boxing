class_name SaveService
extends RefCounted

const SAVE_PATH := "user://career_v2.json"
const BACKUP_PATH := "user://career_v2.backup.json"
const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1

static func save_game(state: Dictionary) -> bool:
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
    if not state.is_empty(): return state
    state = _load_from(BACKUP_PATH)
    if not state.is_empty(): return state
    return _load_legacy_v1()

static func _load_from(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY: return {}
    if int(parsed.get("schema", -1)) != SCHEMA_VERSION: return {}
    var payload_text := str(parsed.get("payload_text", ""))
    if payload_text.is_empty(): return {}
    if str(parsed.get("checksum", "")) != _sha256(payload_text): return {}
    var payload = JSON.parse_string(payload_text)
    if typeof(payload) != TYPE_DICTIONARY: return {}
    if not _validate_payload(payload): return {}
    return payload

static func _load_legacy_v1() -> Dictionary:
    for path in ["user://career_v1.json", "user://career_v1.backup.json"]:
        if not FileAccess.file_exists(path): continue
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
        if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema", -1)) != LEGACY_SCHEMA_VERSION: continue
        var payload_text := str(parsed.get("payload_text", ""))
        if payload_text.is_empty() or str(parsed.get("checksum", "")) != _sha256(payload_text): continue
        var payload = JSON.parse_string(payload_text)
        if typeof(payload) != TYPE_DICTIONARY: continue
        var migrated := _migrate_v1(payload)
        if _validate_payload(migrated):
            save_game(migrated)
            return migrated
    return {}

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
    return {"phase":"camp","boxer":boxer,"career":career,"last_camp_action":"","selected_opponent":"","last_result":"","last_fight_summary":{},"last_weigh_in":{},"pending_event":{},"fight_seed":0,"active_fight":{}}

static func _validate_payload(payload: Dictionary) -> bool:
    for key in ["boxer", "career", "phase"]:
        if not payload.has(key): return false
    var boxer = payload.get("boxer", {})
    for key in ["name","power","speed","technique","defense","conditioning","fatigue","health","weight_kg","trait_id","modifiers","injury"]:
        if not boxer.has(key): return false
    var career = payload.get("career", {})
    for key in ["age_months","money","reputation","wins","losses","draws","fights","career_points","tier","rank","champion","finished","ending"]:
        if not career.has(key): return false
    if int(boxer.health) < 0 or int(boxer.health) > 100: return false
    if int(boxer.fatigue) < 0 or int(boxer.fatigue) > 100: return false
    if int(career.career_points) < 0 or int(career.career_points) > 100: return false
    return true

static func _sha256(text: String) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(text.to_utf8_buffer())
    return context.finish().hex_encode()
