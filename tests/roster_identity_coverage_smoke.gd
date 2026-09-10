extends SceneTree

const POLICY_PATH := "res://data/visual_identity_policy.json"
const OPPONENTS_PATH := "res://data/opponents.json"
const UNIQUE_ROOT := "res://assets/visual/v18/fighters/opponents"

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
    var opponents: Variant = JSON.parse_string(FileAccess.get_file_as_string(OPPONENTS_PATH))
    _check(typeof(policy) == TYPE_DICTIONARY, "visual identity policy is not a dictionary")
    _check(typeof(opponents) == TYPE_ARRAY, "opponents fixture is not an array")
    if typeof(policy) != TYPE_DICTIONARY or typeof(opponents) != TYPE_ARRAY:
        _finish()
        return

    var unique_ids: Array = policy.get("unique_ids", [])
    var fallback_ids: Array = policy.get("fallback_ids", [])
    var expected: Dictionary = {}
    for value in unique_ids:
        var opponent_id := str(value)
        _check(not expected.has(opponent_id), "duplicate visual identity policy id: " + opponent_id)
        expected[opponent_id] = "unique"
    for value in fallback_ids:
        var opponent_id := str(value)
        _check(not expected.has(opponent_id), "identity id appears in both policy sets: " + opponent_id)
        expected[opponent_id] = "fallback"

    _check(opponents.size() == expected.size(), "visual identity policy must classify every roster opponent")
    var seen: Dictionary = {}
    for item in opponents:
        if typeof(item) != TYPE_DICTIONARY:
            _check(false, "opponent entry is not a dictionary")
            continue
        var opponent_id := str(item.get("id", ""))
        var opponent_name := str(item.get("name", ""))
        _check(not opponent_id.is_empty(), "opponent id is empty")
        _check(not opponent_name.is_empty(), "opponent name is empty: " + opponent_id)
        _check(expected.has(opponent_id), "opponent missing from visual identity policy: " + opponent_id)
        _check(not seen.has(opponent_id), "duplicate opponent id: " + opponent_id)
        seen[opponent_id] = true
        _check(VisualAssetCatalog.opponent_country_badge(opponent_name) != "INT", "opponent country badge is unresolved: " + opponent_name)

        var should_be_unique := str(expected.get(opponent_id, "")) == "unique"
        var has_unique := VisualAssetCatalog.has_unique_identity_for_name(opponent_name)
        _check(has_unique == should_be_unique, "visual identity coverage mismatch: %s expected=%s actual=%s" % [opponent_id, str(should_be_unique), str(has_unique)])
        if not should_be_unique:
            continue

        var identity_path := VisualAssetCatalog.opponent_identity_path_for_name(opponent_name)
        _check(identity_path.ends_with("/%s.webp" % opponent_id), "unique identity path mismatch: " + opponent_id)
        var fighter := VisualAssetCatalog.identity_fighter_texture_for_name(opponent_name)
        var portrait := VisualAssetCatalog.identity_portrait_texture_for_name(opponent_name)
        _check(fighter != null, "unique fighter failed to load: " + opponent_id)
        _check(portrait != null, "unique portrait failed to load: " + opponent_id)
        if fighter != null:
            _check(fighter.get_height() > fighter.get_width() * 1.8, "unique fighter lost full-body aspect: " + opponent_id)
        if portrait is AtlasTexture and fighter != null:
            _check((portrait as AtlasTexture).atlas == fighter, "portrait/live fighter source diverged: " + opponent_id)

    for opponent_id in expected.keys():
        _check(seen.has(opponent_id), "visual identity policy references missing roster id: " + str(opponent_id))

    var dir := DirAccess.open(UNIQUE_ROOT)
    _check(dir != null, "unique opponent identity directory is missing")
    if dir != null:
        var actual_unique: Dictionary = {}
        dir.list_dir_begin()
        while true:
            var filename := dir.get_next()
            if filename.is_empty():
                break
            if dir.current_is_dir() or not filename.ends_with(".webp"):
                continue
            actual_unique[filename.trim_suffix(".webp")] = true
        dir.list_dir_end()
        _check(actual_unique.size() == unique_ids.size(), "unique identity directory count does not match policy")
        for opponent_id in actual_unique.keys():
            _check(opponent_id in unique_ids, "unclassified bespoke identity file: " + str(opponent_id))

    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("roster-identity-coverage-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
