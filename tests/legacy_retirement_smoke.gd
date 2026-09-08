extends SceneTree

const StateScript = preload("res://scripts/core/game_state_v12.gd")
const Legacy = preload("res://scripts/core/legacy_service.gd")
const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    game_state = StateScript.new()
    get_root().add_child(game_state)
    await process_frame

    _test_definition_contract()
    _test_lifetime_peak_and_candidate_generation()
    _test_exactly_one_legacy_and_persistence()
    _test_next_generation_preserves_legacy_and_history()
    _test_duplicate_legacy_is_allowed_across_generations()
    _finish()

func _test_definition_contract() -> void:
    var definitions: Array = Legacy.definitions()
    _check(definitions.size() == 15, "expected 15 initial legacy definitions")
    var ids: Dictionary = {}
    var tier_counts: Dictionary = {}
    for value in definitions:
        var definition: Dictionary = value
        var legacy_id := str(definition.get("id", ""))
        _check(not legacy_id.is_empty(), "legacy definition missing id")
        _check(not ids.has(legacy_id), "legacy definition id must be unique: %s" % legacy_id)
        ids[legacy_id] = true
        var tier := str(definition.get("tier", ""))
        tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
        _check(str(definition.get("name", "")).length() > 0, "legacy definition missing name: %s" % legacy_id)
        _check(typeof(definition.get("effect", {})) == TYPE_DICTIONARY, "legacy effect must be data-driven: %s" % legacy_id)
        _check(str(definition.get("stacking", "")) in ["additive", "diminishing", "capped"], "invalid stacking rule: %s" % legacy_id)
    for tier in ["early_pro", "mid_pro", "ranked", "title_contender", "world_class"]:
        _check(int(tier_counts.get(tier, 0)) >= 3, "legacy tier needs at least three candidates: %s" % tier)

func _test_lifetime_peak_and_candidate_generation() -> void:
    game_state.state.career.career_points = 82
    game_state._sync_progression()
    _check(int(game_state.state.career_state.get("career_high_points", -1)) == 82, "career high was not recorded at peak")
    var peak_rank := int(game_state.state.career_state.get("career_high_rank", 50))

    game_state.state.career.career_points = 52
    game_state._sync_progression()
    _check(int(game_state.state.career_state.get("career_high_points", -1)) == 82, "career high regressed after ranking drop")
    _check(int(game_state.state.career_state.get("career_high_rank", 50)) == peak_rank, "career high rank regressed after ranking drop")

    game_state.state.career.finished = true
    game_state.state.career.ending = "loss_retirement"
    Save.save_game(game_state.state)

    var profile: Dictionary = game_state.retirement_legacy_profile()
    _check(str(profile.get("legacy_tier", "")) == "title_contender", "legacy tier must use lifetime peak instead of final rank")
    _check(str(profile.get("flavor", "")) == "패배에서 건진 해답", "retirement flavor must remain separate from legacy tier")

    var candidates: Array = game_state.retirement_legacy_candidates()
    _check(candidates.size() == 3, "retirement must offer exactly three candidates in the initial data set")
    for value in candidates:
        var candidate: Dictionary = value
        _check(str(candidate.get("tier", "")) == "title_contender", "candidate tier does not match lifetime achievement")

func _test_exactly_one_legacy_and_persistence() -> void:
    var candidates: Array = game_state.retirement_legacy_candidates()
    if candidates.size() < 2:
        _check(false, "candidate fixture missing for one-legacy test")
        return
    var first_id := str(candidates[0].get("id", ""))
    var second_id := str(candidates[1].get("id", ""))

    var selected: Dictionary = game_state.select_retirement_legacy(first_id)
    _check(bool(selected.get("ok", false)), "first retirement legacy selection failed")
    var slots: Array = game_state.state.meta_state.get("legacy_slots", [])
    _check(slots.size() == 1, "one retirement must append exactly one legacy")
    if not slots.is_empty():
        var instance: Dictionary = slots[0]
        _check(str(instance.get("definition_id", "")) == first_id, "legacy instance did not reference the chosen definition")
        _check(not instance.has("effect"), "legacy instance must not copy static definition effects")
        _check(int(instance.get("source_generation", 0)) == 1, "legacy source generation mismatch")
        _check(str(instance.get("source_flavor", "")) == "패배에서 건진 해답", "legacy instance missing retirement flavor")

    var rejected: Dictionary = game_state.select_retirement_legacy(second_id)
    _check(not bool(rejected.get("ok", true)), "same retired boxer was allowed to select a second legacy")
    _check(str(rejected.get("reason", "")) == "already_selected", "second legacy rejection reason mismatch")
    _check(game_state.state.meta_state.get("legacy_slots", []).size() == 1, "rejected second selection changed legacy slots")

    var loaded: Dictionary = Save.load_game()
    _check(int(loaded.get("meta_state", {}).get("generation", 0)) == 1, "generation did not persist with selected legacy")
    _check(loaded.get("meta_state", {}).get("legacy_slots", []).size() == 1, "selected legacy did not survive save round-trip")

func _test_next_generation_preserves_legacy_and_history() -> void:
    var old_instance: Dictionary = game_state.state.meta_state.legacy_slots[0].duplicate(true)
    var advanced: Dictionary = game_state.start_next_generation()
    _check(bool(advanced.get("ok", false)), "next generation could not start after legacy selection")
    _check(int(game_state.state.meta_state.get("generation", 0)) == 2, "generation did not increment")
    _check(game_state.state.meta_state.get("legacy_slots", []).size() == 1, "legacy was lost when starting the next generation")
    _check(str(game_state.state.meta_state.legacy_slots[0].get("definition_id", "")) == str(old_instance.get("definition_id", "")), "legacy definition changed across generation handoff")
    _check(game_state.state.meta_state.get("lineage_history", []).size() == 1, "retired boxer was not archived to lineage history")
    if not game_state.state.meta_state.lineage_history.is_empty():
        var history: Dictionary = game_state.state.meta_state.lineage_history[0]
        _check(int(history.get("generation", 0)) == 1, "lineage history source generation mismatch")
        _check(str(history.get("legacy_definition_id", "")) == str(old_instance.get("definition_id", "")), "lineage history missing chosen legacy")
        _check(int(history.get("career_high_points", -1)) == 82, "lineage history lost lifetime peak")
    _check(not bool(game_state.state.career.get("finished", true)), "next generation started as a finished career")
    _check(int(game_state.state.career.get("fights", -1)) == 0, "next generation did not reset current career fights")
    _check(bool(game_state.state.get("first_launch_acknowledged", false)), "next generation must not reopen the product launch gate")

func _test_duplicate_legacy_is_allowed_across_generations() -> void:
    var first_id := str(game_state.state.meta_state.legacy_slots[0].get("definition_id", ""))
    game_state.state.career.career_points = 82
    game_state._sync_progression()
    game_state.state.career.finished = true
    game_state.state.career.ending = "loss_retirement"
    Save.save_game(game_state.state)

    var candidates: Array = game_state.retirement_legacy_candidates()
    var found_duplicate := false
    for value in candidates:
        var definition: Dictionary = value
        if str(definition.get("id", "")) == first_id:
            found_duplicate = true
            break
    _check(found_duplicate, "same legacy definition was not offered again for a later generation")
    if not found_duplicate:
        return

    var selected: Dictionary = game_state.select_retirement_legacy(first_id)
    _check(bool(selected.get("ok", false)), "duplicate legacy was incorrectly forbidden across generations")
    var slots: Array = game_state.state.meta_state.get("legacy_slots", [])
    _check(slots.size() == 2, "duplicate legacy did not consume a separate active slot")
    if slots.size() == 2:
        _check(str(slots[0].get("definition_id", "")) == str(slots[1].get("definition_id", "")), "duplicate legacy definitions differ unexpectedly")
        _check(int(slots[1].get("source_generation", 0)) == 2, "duplicate legacy source generation mismatch")

func _finish() -> void:
    if is_instance_valid(game_state):
        game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("legacy-retirement-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.PREVIOUS_SAVE_PATH, Save.PREVIOUS_BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
            _check(err == OK, "failed to remove fixture file: %s" % path)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
