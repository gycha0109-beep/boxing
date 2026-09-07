extends SceneTree

const StateV03 = preload("res://scripts/core/game_state_v03.gd")
const CombatV03 = preload("res://scripts/core/combat_engine_v03.gd")
const Save = preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var game_state

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    game_state = StateV03.new()
    get_root().add_child(game_state)
    await process_frame

    _test_identity_created()
    _test_scouting_to_game_plan_flow()
    _test_v02_additive_normalization()

    if is_instance_valid(game_state):
        game_state.queue_free()
    _cleanup_save_files()

    if failures.is_empty():
        print("v03-gameplan-smoke: PASS")
        quit(0)
    for failure in failures:
        push_error(failure)
    quit(1)

func _test_identity_created() -> void:
    var boxer: Dictionary = game_state.state.get("boxer", {})
    _check(not str(boxer.get("identity_id", "")).is_empty(), "new career missing identity id")
    _check(str(boxer.get("identity_id", "")) != "balanced", "new career should roll a meaningful identity")
    _check(not str(boxer.get("identity_signature", "")).is_empty(), "new career missing identity signature")

func _test_scouting_to_game_plan_flow() -> void:
    var opponents = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    _check(typeof(opponents) == TYPE_ARRAY and not opponents.is_empty(), "opponent data missing")
    if typeof(opponents) != TYPE_ARRAY or opponents.is_empty():
        return

    var opponent: Dictionary = opponents[0]
    _check(not opponent.get("scouting", {}).is_empty(), "opponent scouting missing")
    _check(not opponent.get("tendencies", {}).is_empty(), "opponent tendencies missing")

    game_state.state.phase = "fight_offer"
    game_state.select_opponent(opponent)
    _check(str(game_state.state.phase) == "game_plan", "select_opponent must enter game_plan phase")
    _check(game_state.state.get("last_weigh_in", {}).is_empty(), "weigh-in must not resolve before game-plan choice")

    var base_boxer: Dictionary = game_state.state.boxer.duplicate(true)
    var chosen := game_state.select_game_plan("outside_boxing")
    _check(bool(chosen.get("ok", false)), "outside_boxing game plan was rejected")
    _check(str(game_state.state.phase) == "fight", "game plan must advance to fight")
    _check(str(game_state.state.selected_game_plan) == "outside_boxing", "selected game plan not persisted")
    _check(not game_state.state.get("last_weigh_in", {}).is_empty(), "weigh-in did not resolve after game-plan choice")

    var fight_boxer: Dictionary = game_state.get_fight_boxer()
    _check(str(fight_boxer.get("game_plan", {}).get("id", "")) == "outside_boxing", "fight boxer missing game-plan payload")
    _check(int(fight_boxer.speed) == clamp(int(base_boxer.speed) + 2, 1, 100), "outside_boxing global speed modifier missing")
    _check(int(fight_boxer.technique) == clamp(int(base_boxer.technique) + 2, 1, 100), "outside_boxing global technique modifier missing")
    _check(int(fight_boxer.power) == clamp(int(base_boxer.power) - 2, 1, 100), "outside_boxing power trade-off missing")

    var combat = CombatV03.new(int(game_state.state.fight_seed))
    combat.start(fight_boxer, opponent)
    var seen_actions: Dictionary = {}
    for i in range(40):
        seen_actions[combat._choose_opponent_action()] = true
    for action_id in seen_actions.keys():
        _check(opponent.tendencies.has(action_id), "AI selected action outside opponent tendencies: %s" % action_id)
    combat.resolve_exchange("jab")
    _check(int(combat.exchange_no) == 1, "v0.3 combat did not resolve an exchange")

func _test_v02_additive_normalization() -> void:
    var boxer: Dictionary = game_state.state.boxer
    boxer.erase("identity_id")
    boxer.erase("identity_name")
    boxer.erase("identity_description")
    boxer.erase("identity_signature")
    game_state.state.erase("selected_game_plan")
    game_state.state.phase = "fight"
    var changed := game_state._normalize_v03_state()
    _check(changed, "v0.2-compatible state was not normalized")
    _check(str(game_state.state.boxer.get("identity_id", "")) == "balanced", "legacy state identity fallback failed")
    _check(str(game_state.state.get("selected_game_plan", "")) == "balanced", "legacy in-fight game-plan fallback failed")

func _cleanup_save_files() -> void:
    for path in [Save.SAVE_PATH, Save.BACKUP_PATH, "user://career_v1.json", "user://career_v1.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
