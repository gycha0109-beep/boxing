extends SceneTree

const POLICY_PATH := "res://data/visual_identity_policy.json"
const OPPONENTS_PATH := "res://data/opponents.json"
const UNIQUE_ROOT := "res://assets/visual/v18/fighters/opponents"
const DIEGO_NAME := "디에고 레예스"
const V19_POLISH_OVERLAY := "res://scripts/ui/v19_polish_overlay.gd"

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

    _verify_diego_runtime_sanitation()
    _finish()

func _verify_diego_runtime_sanitation() -> void:
    var path := VisualAssetCatalog.opponent_identity_path_for_name(DIEGO_NAME)
    _check(not path.is_empty() and ResourceLoader.exists(path), "Diego identity source is unavailable for sanitation smoke")
    if path.is_empty() or not ResourceLoader.exists(path):
        return

    var source := load(path) as Texture2D
    _check(source != null, "Diego packaged source texture failed to load")
    if source == null:
        return
    var source_image := source.get_image()
    _check(source_image != null, "Diego packaged source image is unavailable")
    if source_image == null:
        return

    var source_guides := _count_diego_guide_pixels(source_image)
    var source_visible := _count_visible_pixels(source_image)
    _check(source_guides > 0, "Diego packaged source no longer contains the expected construction guides; remove runtime sanitation instead of silently keeping dead cleanup")
    _check(source_visible > 0, "Diego packaged source contains no visible fighter pixels")

    VisualAssetCatalog._texture_cache.erase(path)
    VisualAssetCatalog._identity_cache.erase("named_fighter_" + DIEGO_NAME)
    VisualAssetCatalog._identity_cache.erase("named_portrait_" + DIEGO_NAME)

    var overlay_script := load(V19_POLISH_OVERLAY) as GDScript
    _check(overlay_script != null, "v19 polish overlay failed to load for Diego sanitation smoke")
    if overlay_script == null:
        return
    var overlay: Object = overlay_script.new()
    _check(overlay != null, "v19 polish overlay failed to instantiate for Diego sanitation smoke")
    if overlay == null:
        return
    overlay.call("_sanitize_diego_identity_guides")

    var fighter := VisualAssetCatalog.identity_fighter_texture_for_name(DIEGO_NAME)
    _check(fighter != null, "sanitized Diego fighter texture failed to resolve")
    if fighter == null:
        return
    var cleaned_image := fighter.get_image()
    _check(cleaned_image != null, "sanitized Diego fighter image is unavailable")
    if cleaned_image == null:
        return

    _check(cleaned_image.get_size() == source_image.get_size(), "Diego sanitation changed source texture dimensions")
    var cleaned_guides := _count_diego_guide_pixels(cleaned_image)
    _check(cleaned_guides == 0, "Diego runtime texture still contains red/green construction guide pixels")

    var cleaned_visible := _count_visible_pixels(cleaned_image)
    var removed_visible := source_visible - cleaned_visible
    _check(removed_visible > 0, "Diego sanitation removed no visible guide pixels")
    if source_visible > 0:
        _check(float(removed_visible) / float(source_visible) < 0.05, "Diego sanitation removed too much of the fighter silhouette")

    var used := cleaned_image.get_used_rect()
    _check(used.size.x > cleaned_image.get_width() * 0.30, "Diego sanitized fighter became implausibly narrow")
    _check(used.size.y > cleaned_image.get_height() * 0.70, "Diego sanitized fighter lost full-body height")
    _check(VisualAssetCatalog.texture(path) == fighter, "Diego sanitized texture is not authoritative in the path cache")

    var portrait := VisualAssetCatalog.identity_portrait_texture_for_name(DIEGO_NAME)
    _check(portrait is AtlasTexture, "Diego sanitized portrait is not derived from the live fighter texture")
    if portrait is AtlasTexture:
        _check((portrait as AtlasTexture).atlas == fighter, "Diego portrait/live identity diverged after runtime sanitation")

func _count_diego_guide_pixels(image: Image) -> int:
    var width := image.get_width()
    var height := image.get_height()
    var left_limit := int(round(width * 0.235))
    var right_start := int(round(width * 0.725))
    var y_start := int(round(height * 0.44))
    var y_end := int(round(height * 0.74))
    var count := 0
    for y in range(y_start, y_end):
        for x in range(width):
            if x >= left_limit and x <= right_start:
                continue
            var pixel := image.get_pixel(x, y)
            if pixel.a <= 0.5:
                continue
            var red_guide := pixel.r > 0.32 and pixel.r > pixel.g * 2.2 and pixel.r > pixel.b * 2.0
            var green_guide := pixel.g > 0.25 and pixel.g > pixel.r * 2.2 and pixel.g > pixel.b * 1.45
            if red_guide or green_guide:
                count += 1
    return count

func _count_visible_pixels(image: Image) -> int:
    var count := 0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x, y).a > 0.5:
                count += 1
    return count

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
