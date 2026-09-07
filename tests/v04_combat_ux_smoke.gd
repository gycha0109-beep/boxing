extends SceneTree

const CombatScript = preload("res://scripts/core/combat_engine.gd")
const Presentation = preload("res://scripts/ui/combat_presentation.gd")

var failures: Array[String] = []
var plans: Array = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    plans = _load_array("res://data/game_plans.json")
    _test_locked_telegraph_survives_json_resume()
    _test_counter_trap_miss_read_feedback()
    _test_body_stamina_feedback()
    _test_round_summary()
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("v04-combat-ux-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _test_locked_telegraph_survives_json_resume() -> void:
    var player: Dictionary = _player_with_plan("counter_trap")
    var opponent: Dictionary = _forced_opponent("power", "Telegraph Slugger")
    var combat: RefCounted = CombatScript.new(44001)
    combat.start(player, opponent)

    var first_read: Dictionary = combat.prepare_exchange()
    _check(str(combat.pending_opponent_action) == "power", "prepare_exchange did not lock forced power action")
    _check(str(first_read.get("signal_id", "")) == "committed_attack", "power telegraph signal mismatch")
    _check(int(first_read.get("confidence", 0)) > 0, "telegraph confidence missing")

    var rng_after_first_prepare: String = str(combat.rng.state)
    var second_read: Dictionary = combat.prepare_exchange()
    _check(first_read == second_read, "repeated prepare_exchange changed telegraph")
    _check(str(combat.rng.state) == rng_after_first_prepare, "repeated prepare_exchange consumed RNG")

    var disk_state: Variant = JSON.parse_string(JSON.stringify(combat.export_state()))
    _check(typeof(disk_state) == TYPE_DICTIONARY, "prepared fight state did not survive JSON round-trip")
    if typeof(disk_state) != TYPE_DICTIONARY:
        return

    var restored: RefCounted = CombatScript.new(1)
    restored.restore(player, opponent, disk_state)
    _check(str(restored.pending_opponent_action) == "power", "pending opponent action was not restored")
    _check(str(restored.pending_telegraph.get("signal_id", "")) == str(first_read.get("signal_id", "")), "pending telegraph signal was not restored")
    _check(str(restored.pending_telegraph.get("title", "")) == str(first_read.get("title", "")), "pending telegraph title was not restored")
    _check(int(restored.pending_telegraph.get("confidence", 0)) == int(first_read.get("confidence", 0)), "pending telegraph confidence was not restored")

    var out: Dictionary = restored.resolve_exchange("counter")
    var exchange: Dictionary = out.get("exchange_result", {})
    _check(str(exchange.get("opponent_action", "")) == "power", "restored exchange rerolled opponent action")
    _check(str(exchange.get("first_actor", "")) == "opponent", "counter must react after committed power")
    _check(bool(exchange.get("read_success", false)), "counter trap should mark committed power as read success")
    _check(not bool(exchange.get("read_failed", false)), "read success incorrectly marked as failed")
    _check(not exchange.get("player_event", {}).is_empty(), "structured player event missing")
    _check(not Presentation.exchange_headline(exchange).is_empty(), "presentation headline missing")
    _check(not Presentation.exchange_detail(exchange, str(opponent.name)).is_empty(), "presentation detail missing")

func _test_counter_trap_miss_read_feedback() -> void:
    var player: Dictionary = _player_with_plan("counter_trap")
    var opponent: Dictionary = _forced_opponent("jab", "Jab Reader")
    var combat: RefCounted = CombatScript.new(44002)
    combat.start(player, opponent)
    var telegraph: Dictionary = combat.prepare_exchange()
    _check(str(telegraph.get("signal_id", "")) == "lead_hand", "jab telegraph signal mismatch")

    var out: Dictionary = combat.resolve_exchange("counter")
    var exchange: Dictionary = out.get("exchange_result", {})
    _check(bool(exchange.get("read_failed", false)), "counter trap should fail when target action is jab")
    _check(not bool(exchange.get("read_success", false)), "jab miss-read incorrectly marked success")
    _check(Presentation.exchange_headline(exchange) == "READ FAILED", "miss-read presentation headline mismatch")
    _check(Presentation.exchange_detail(exchange, str(opponent.name)).contains("페널티"), "miss-read explanation missing")

func _test_body_stamina_feedback() -> void:
    var player: Dictionary = _player_with_plan("body_breakdown")
    player.power = 100
    player.speed = 100
    player.technique = 100
    var opponent: Dictionary = _forced_opponent("jab", "Body Fixture")
    opponent.stats.defense = 1
    opponent.stats.speed = 1

    var found_hit: bool = false
    for seed_value in range(1, 60):
        var combat: RefCounted = CombatScript.new(seed_value)
        combat.start(player, opponent)
        combat.opponent_stamina = 45.0
        var out: Dictionary = combat.resolve_exchange("body")
        var exchange: Dictionary = out.get("exchange_result", {})
        var player_event: Dictionary = exchange.get("player_event", {})
        if not bool(player_event.get("hit", false)):
            continue
        found_hit = true
        _check(str(player_event.get("action", "")) == "body", "body fixture did not preserve action id")
        _check(float(player_event.get("target_stamina_damage", 0.0)) >= 8.9, "body hit did not expose stamina damage")
        _check(str(exchange.get("opponent_body_state", "")) == "hurt", "body stamina threshold did not become hurt")
        _check(Presentation.body_state_label(str(exchange.get("opponent_body_state", ""))) == "몸통 데미지 누적", "body state presentation mismatch")
        var headline: String = Presentation.exchange_headline(exchange)
        _check(headline in ["BODY HIT", "KNOCKDOWN!"], "body hit presentation lost body/KO feedback")
        break
    _check(found_hit, "could not produce deterministic body hit fixture")

func _test_round_summary() -> void:
    var player: Dictionary = _player_with_plan("balanced")
    var opponent: Dictionary = _forced_opponent("guard", "Round Fixture")
    var combat: RefCounted = CombatScript.new(44003)
    combat.start(player, opponent)
    var final_exchange: Dictionary = {}
    for _i in range(3):
        final_exchange = combat.resolve_exchange("guard").get("exchange_result", {})
    _check(bool(final_exchange.get("round_ended", false)), "third exchange did not close round")
    _check(int(final_exchange.get("completed_round", 0)) == 1, "completed round number mismatch")
    var card: Array = final_exchange.get("round_card", [])
    _check(card.size() == 2, "round card missing from structured result")
    var summary: String = Presentation.round_summary(final_exchange, "PLAYER", str(opponent.name))
    _check(summary.contains("ROUND 1 종료"), "round summary title missing")
    _check(summary.contains("예상 점수"), "round summary score missing")

func _player_with_plan(plan_id: String) -> Dictionary:
    return {
        "power": 60,
        "speed": 70,
        "technique": 75,
        "defense": 82,
        "conditioning": 82,
        "fatigue": 0,
        "health": 100,
        "modifiers": {},
        "game_plan": _plan(plan_id)
    }

func _forced_opponent(action_id: String, opponent_name: String) -> Dictionary:
    var tendencies := {"jab":0.0,"power":0.0,"body":0.0,"guard":0.0,"counter":0.0}
    tendencies[action_id] = 1.0
    return {
        "id": "v04-fixture-" + action_id,
        "name": opponent_name,
        "style": "slugger",
        "rank": 1,
        "tendencies": tendencies,
        "stats": {"power":8,"speed":15,"technique":15,"defense":80,"conditioning":80}
    }

func _plan(plan_id: String) -> Dictionary:
    for plan in plans:
        if str(plan.get("id", "")) == plan_id:
            return plan.duplicate(true)
    return {"id":"balanced","global_stats":{},"action_modifiers":{}}

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
