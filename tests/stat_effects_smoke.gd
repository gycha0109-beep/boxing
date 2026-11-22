extends SceneTree

const CombatScript = preload("res://scripts/core/combat_engine.gd")
const Presentation = preload("res://scripts/ui/combat_presentation.gd")

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_stat_help_copy()
    _test_power_and_technique_roles()
    _test_speed_evasion()
    _test_defense_effects()
    _test_conditioning_effects()
    _test_evasion_feedback()
    _finish()

func _test_stat_help_copy() -> void:
    var game_state := root.get_node_or_null("GameState")
    _check(game_state != null, "GameState autoload is missing")
    if game_state == null:
        return
    for stat in ["power", "speed", "technique", "defense", "conditioning"]:
        var description := str(game_state.call("stat_help", stat))
        _check(not description.is_empty(), "missing player-facing explanation for " + stat)

func _test_power_and_technique_roles() -> void:
    var combat: RefCounted = CombatScript.new(51001)
    _check(combat._power_damage_multiplier(80.0) > combat._power_damage_multiplier(40.0), "power must increase punch damage")
    _check(is_equal_approx(combat._technique_damage_multiplier(50.0), 1.0), "technique damage baseline must be neutral at 50")
    _check(combat._technique_damage_multiplier(100.0) > combat._technique_damage_multiplier(50.0), "technique should provide only a small execution bonus")
    _check(combat._technique_damage_variance(100.0) < combat._technique_damage_variance(50.0), "technique must reduce punch damage variance")

    var actor := {"technique":80, "speed":50}
    var target := {"defense":50, "speed":50}
    _check(is_equal_approx(combat._technique_accuracy_adjustment(actor, target, "jab"), 0.096), "technique accuracy adjustment mismatch")
    _check(is_equal_approx(combat._technique_accuracy_adjustment(actor, target, "counter"), 0.126), "counter-specific technique bonus missing")

func _test_speed_evasion() -> void:
    var combat: RefCounted = CombatScript.new(51002)
    _check(is_equal_approx(combat._evasion_chance({"speed":50}, {"speed":80}), 0.09), "30-point speed advantage should grant 9% evasion")
    _check(is_equal_approx(combat._evasion_chance({"speed":80}, {"speed":50}), 0.0), "slower defender must not gain speed evasion")
    _check(is_equal_approx(combat._evasion_chance({"speed":1}, {"speed":100}), 0.15), "speed evasion cap must be 15%")

func _test_defense_effects() -> void:
    var combat: RefCounted = CombatScript.new(51003)
    _check(is_equal_approx(combat._defense_damage_multiplier(50.0), 1.0), "defense baseline must be neutral at 50")
    _check(is_equal_approx(combat._defense_damage_multiplier(100.0), 0.90), "defense 100 must reduce incoming damage by 10%")
    _check(combat._defense_damage_multiplier(1.0) > 1.0, "very low defense should increase incoming damage")
    _check(is_equal_approx(combat._ko_resistance_multiplier({"defense":50, "conditioning":50}), 1.0), "KO resistance baseline must be neutral")
    _check(combat._ko_resistance_multiplier({"defense":100, "conditioning":100}) < 1.0, "high defense and conditioning must reduce KO risk")

func _test_conditioning_effects() -> void:
    var combat: RefCounted = CombatScript.new(51004)
    _check(is_equal_approx(combat._stamina_cost_multiplier(50.0), 1.0), "conditioning baseline stamina cost must remain unchanged at 50")
    _check(is_equal_approx(combat._stamina_cost_multiplier(70.0), 0.84), "conditioning 70 must reduce action stamina costs by 16%")
    _check(is_equal_approx(combat._stamina_cost_multiplier(100.0), 0.65), "conditioning 100 stamina cost floor mismatch")
    _check(is_equal_approx(combat._round_stamina_recovery(70.0), 14.7), "conditioning 70 round recovery mismatch")
    _check(is_equal_approx(combat._round_stamina_recovery(100.0), 19.5), "conditioning 100 round recovery mismatch")
    _check(is_equal_approx(combat._body_stamina_damage_multiplier(70.0), 0.84), "conditioning 70 body-shot resistance mismatch")
    _check(is_equal_approx(combat._body_stamina_damage_multiplier(100.0), 0.65), "conditioning 100 body-shot resistance floor mismatch")
    _check(is_equal_approx(combat._fatigue_resistance_multiplier(100.0), 0.60), "conditioning 100 fatigue resistance mismatch")

func _test_evasion_feedback() -> void:
    var found_evasion := false
    var opponent := {
        "id":"fast-evader",
        "name":"빠른 상대",
        "style":"out_boxer",
        "tendencies":{"jab":0.0,"power":0.0,"body":0.0,"guard":1.0,"counter":0.0},
        "stats":{"power":40,"speed":100,"technique":50,"defense":1,"conditioning":50}
    }
    var player := {
        "power":50,"speed":10,"technique":100,"defense":50,"conditioning":50,
        "fatigue":0,"health":100,"modifiers":{},"game_plan":{}
    }
    for seed_value in range(1, 301):
        var combat: RefCounted = CombatScript.new(seed_value)
        combat.start(player, opponent)
        var out: Dictionary = combat.resolve_exchange("jab")
        var exchange: Dictionary = out.get("exchange_result", {})
        var player_event: Dictionary = exchange.get("player_event", {})
        if bool(player_event.get("evaded", false)):
            found_evasion = true
            _check(Presentation.exchange_headline(exchange) == "상대 회피", "evasion headline was not shown")
            _check(Presentation.exchange_detail(exchange, "빠른 상대").contains("빠른 움직임"), "evasion detail was not shown")
            break
    _check(found_evasion, "high-speed opponent never produced an evasion event in deterministic seed sweep")

func _finish() -> void:
    if failures.is_empty():
        print("stat-effects-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
