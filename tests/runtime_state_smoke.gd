extends SceneTree

const Save = preload("res://scripts/core/save_service.gd")
const Combat = preload("res://scripts/core/combat_engine.gd")

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_save_round_trip_and_backup()
    _test_legacy_v1_migration()
    _test_combat_resume_rng_round_trip()
    _cleanup_save_files()
    if failures.is_empty():
        print("runtime-state-smoke: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _test_save_round_trip_and_backup() -> void:
    _cleanup_save_files()
    var first := _valid_state(111000, "첫 세이브")
    _check(Save.save_game(first), "primary save write failed")
    var loaded := Save.load_game()
    _check(int(loaded.get("career", {}).get("money", -1)) == 111000, "primary save round-trip failed")

    var second := _valid_state(222000, "두 번째 세이브")
    _check(Save.save_game(second), "second save write failed")
    var file := FileAccess.open(Save.SAVE_PATH, FileAccess.WRITE)
    _check(file != null, "could not open primary save for corruption fixture")
    if file:
        file.store_string("{corrupt-primary")
        file.close()
    loaded = Save.load_game()
    _check(int(loaded.get("career", {}).get("money", -1)) == 111000, "known-good backup fallback failed")

func _test_legacy_v1_migration() -> void:
    _cleanup_save_files()
    var old_payload := {
        "boxer": {
            "name": "Legacy Boxer",
            "power": 51, "speed": 52, "technique": 53, "defense": 54, "conditioning": 55,
            "fatigue": 7, "health": 93
        },
        "career": {
            "age": 19, "money": 135000, "reputation": 6,
            "wins": 2, "losses": 1, "draws": 0, "fights": 3, "rank": 41
        }
    }
    var payload_text := JSON.stringify(old_payload)
    var envelope := {"schema": 1, "payload_text": payload_text, "checksum": _sha256(payload_text)}
    var legacy := FileAccess.open("user://career_v1.json", FileAccess.WRITE)
    _check(legacy != null, "could not create legacy fixture")
    if legacy:
        legacy.store_string(JSON.stringify(envelope))
        legacy.close()
    var migrated := Save.load_game()
    _check(int(migrated.get("career", {}).get("age_months", -1)) == 228, "legacy age migration failed")
    _check(str(migrated.get("boxer", {}).get("trait_id", "")) == "workhorse", "legacy default trait migration failed")
    _check(FileAccess.file_exists(Save.SAVE_PATH), "migrated v2 save was not persisted")

func _test_combat_resume_rng_round_trip() -> void:
    var opponents = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    _check(typeof(opponents) == TYPE_ARRAY and opponents.size() > 0, "opponent fixture missing")
    if typeof(opponents) != TYPE_ARRAY or opponents.is_empty():
        return
    var opponent: Dictionary = opponents[0]
    var player := {
        "power": 55, "speed": 58, "technique": 57, "defense": 90, "conditioning": 90,
        "fatigue": 0, "health": 100, "modifiers": {}
    }
    var uninterrupted = Combat.new(24681357)
    uninterrupted.start(player, opponent)
    uninterrupted.resolve_exchange("guard")
    _check(not uninterrupted.finished, "resume fixture ended before checkpoint")
    if uninterrupted.finished:
        return
    var checkpoint: Dictionary = uninterrupted.export_state()
    _check(typeof(checkpoint.get("rng_state", 0)) == TYPE_STRING, "RNG state must serialize as a string")

    # Force a JSON round-trip so this matches the on-disk save path, including numeric/string conversion.
    var checkpoint_json := JSON.stringify(checkpoint)
    var disk_checkpoint = JSON.parse_string(checkpoint_json)
    _check(typeof(disk_checkpoint) == TYPE_DICTIONARY, "checkpoint JSON round-trip failed")
    if typeof(disk_checkpoint) != TYPE_DICTIONARY:
        return

    uninterrupted.resolve_exchange("jab")
    var expected: Dictionary = uninterrupted.export_state()

    var resumed = Combat.new(24681357)
    resumed.restore(player, opponent, disk_checkpoint)
    resumed.resolve_exchange("jab")
    var actual: Dictionary = resumed.export_state()

    for key in ["round_no", "exchange_no", "finished", "result", "rng_state"]:
        _check(str(actual.get(key)) == str(expected.get(key)), "combat resume mismatch: %s" % key)
    for key in ["player_hp", "opponent_hp", "player_stamina", "opponent_stamina", "player_round_score", "opponent_round_score"]:
        _check(is_equal_approx(float(actual.get(key, 0.0)), float(expected.get(key, 0.0))), "combat resume float mismatch: %s" % key)
    _check(JSON.stringify(actual.get("cards", [])) == JSON.stringify(expected.get("cards", [])), "combat resume scorecards diverged")
    _check(JSON.stringify(actual.get("log", [])) == JSON.stringify(expected.get("log", [])), "combat resume log diverged")

func _valid_state(money: int, label: String) -> Dictionary:
    return {
        "phase": "camp",
        "boxer": {
            "name": label,
            "power": 50, "speed": 50, "technique": 50, "defense": 50, "conditioning": 50,
            "fatigue": 0, "health": 100, "weight_kg": 61.8,
            "trait_id": "workhorse", "trait_name": "훈련광", "modifiers": {}, "injury": {}
        },
        "career": {
            "age_months": 228, "money": money, "reputation": 0,
            "wins": 0, "losses": 0, "draws": 0, "fights": 0,
            "career_points": 0, "tier": "prospect", "rank": 50,
            "champion": false, "finished": false, "ending": ""
        },
        "last_camp_action": "", "selected_opponent": "", "last_result": "",
        "last_fight_summary": {}, "last_weigh_in": {}, "pending_event": {},
        "fight_seed": 0, "active_fight": {}
    }

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
            _check(err == OK, "failed to remove fixture file: %s" % path)

func _sha256(text: String) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(text.to_utf8_buffer())
    return context.finish().hex_encode()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
