class_name CombatEngineV03
extends "res://scripts/core/combat_engine.gd"

const ACTION_ORDER := ["jab", "power", "body", "guard", "counter"]
const TRAINABLE_STATS := ["power", "speed", "technique", "defense", "conditioning"]

func _choose_opponent_action() -> String:
    var tendencies: Dictionary = opponent.get("tendencies", {})
    if tendencies.is_empty():
        return super._choose_opponent_action()

    var total := 0.0
    for action_id in ACTION_ORDER:
        total += max(0.0, float(tendencies.get(action_id, 0.0)))
    if total <= 0.0:
        return super._choose_opponent_action()

    var roll := rng.randf() * total
    var cursor := 0.0
    for action_id in ACTION_ORDER:
        cursor += max(0.0, float(tendencies.get(action_id, 0.0)))
        if roll <= cursor:
            return action_id
    return "jab"

func _perform(is_player: bool, action_id: String, target_action: String) -> void:
    if not is_player:
        super._perform(is_player, action_id, target_action)
        return

    var plan: Dictionary = player.get("game_plan", {})
    var action_modifiers: Dictionary = plan.get("action_modifiers", {})
    var modifiers: Dictionary = action_modifiers.get(action_id, {})
    if modifiers.is_empty():
        super._perform(is_player, action_id, target_action)
        return

    var original_stats: Dictionary = {}
    for stat in TRAINABLE_STATS:
        if modifiers.has(stat):
            original_stats[stat] = player.get(stat, 50)
            player[stat] = clamp(int(player.get(stat, 50)) + int(modifiers[stat]), 1, 100)

    super._perform(is_player, action_id, target_action)

    for stat in original_stats.keys():
        player[stat] = original_stats[stat]
