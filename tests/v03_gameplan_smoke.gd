extends SceneTree

const StateScript = preload("res://scripts/core/game_state.gd")
const CombatScript = preload("res://scripts/core/combat_engine.gd")
const Save = preload("res://scripts/core/save_service.gd")
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

var failures: Array[String] = []
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _cleanup_save_files()
    game_state = StateScript.new()
    get_root().add_child(game_state)
    await process_frame

    _test_identity_created()
    _test_scouting_to_game_plan_flow()
    _test_counter_reacts_after_committed_attack()
    _test_v02_additive_normalization()
    _finish()

func _finish() -> void:
    if is_instance_valid(game_state):
        game_state.queue_free()
    _cleanup_save_files()
    if failures.is_empty():
        print("v03-gameplan-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _test_identity_created() -> void:
    var boxer: Dictionary = game_state.state.get("boxer", {})
    _check(not str(boxer.get("identity_id", "")).is_empty(), "new career missing identity id")
    _check(str(boxer.get("identity_id", "")) != "balanced", "new career should roll a meaningful identity")
    _check(not str(boxer.get("identity_signature", "")).is_empty(), "new career missing identity signature")

func _test_scouting_to_game_plan_flow() -> void:
    var opponents: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
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
    var chosen: Dictionary = game_state.select_game_plan("outside_boxing")
    _check(bool(chosen.get("ok", false)), "outside_boxing game plan was rejected")
    _check(str(game_state.state.phase) == "fight", "game plan must advance to fight")
    _check(str(game_state.state.selected_game_plan) == "outside_boxing", "selected game plan not persisted")
    _check(not game_state.state.get("last_weigh_in", {}).is_empty(), "weigh-in did not resolve after game-plan choice")

    var fight_boxer: Dictionary = game_state.get_fight_boxer()
    var plan: Dictionary = fight_boxer.get("game_plan", {})
    _check(str(plan.get("id", "")) == "outside_boxing", "fight boxer missing game-plan payload")
    var global_stats: Dictionary = plan.get("global_stats", {})
    for stat in TRAINABLE_STATS:
        var expected: int = int(base_boxer.get(stat, 50))
        if global_stats.has(stat):
            expected = clamp(expected + int(global_stats[stat]), 1, 100)
        _check(int(fight_boxer.get(stat, -1)) == expected, "outside_boxing global modifier mismatch: %s" % stat)

    var combat: RefCounted = CombatScript.new(int(game_state.state.fight_seed))
    combat.start(fight_boxer, opponent)
    var seen_actions: Dictionary = {}
    for _i in range(40):
        seen_actions[combat._choose_opponent_action()] = true
    for action_id in seen_actions.keys():
        _check(opponent.tendencies.has(action_id), "AI selected action outside opponent tendencies: %s" % action_id)
    combat.resolve_exchange("jab")
    _check(int(combat.exchange_no) == 1, "v0.3 combat did not resolve an exchange")

func _test_counter_reacts_after_committed_attack() -> void:
    var opponent := {
        "id": "counter-order-fixture",
        "name": "Order Fixture",
        "style": "slugger",
        "stats": {"power":1,"speed":1,"technique":1,"defense":90,"conditioning":90},
        "tendencies": {"jab":0.0,"power":1.0,"body":0.0,"guard":0.0,"counter":0.0}
    }
    var player := {
        "power":40,"speed":100,"technique":80,"defense":100,"conditioning":100,
        "fatigue":0,"health":100,"modifiers":{},"game_plan":{}
    }
    var combat: RefCounted = CombatScript.new(424242)
    combat.start(player, opponent)
    var out: Dictionary = combat.resolve_exchange("counter")
    _check(str(out.get("opponent_action", "")) == "power", "counter order fixture did not force power action")
    _check(combat.log.size() >= 2, "counter order fixture did not execute both actors")
    if combat.log.size() >= 2:
        _check(str(combat.log[0]).begins_with("Order Fixture"), "counter must yield initiative to committed attack")
        _check(str(combat.log[1]).begins_with("나"), "counter must execute after committed attack")

func _test_v02_additive_normalization() -> void:
    var boxer: Dictionary = game_state.state.boxer
    boxer.erase("identity_id")
    boxer.erase("identity_name")
    boxer.erase("identity_description")
    boxer.erase("identity_signature")
    game_state.state.erase("selected_game_plan")
    game_state.state.phase = "fight"
    var changed: bool = game_state._normalize_v03_state()
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
