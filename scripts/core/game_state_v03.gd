extends "res://scripts/core/game_state.gd"

var fighter_identities: Array = []
var game_plans: Array = []

func _ready() -> void:
    fighter_identities = _load_json_array("res://data/fighter_identities.json")
    game_plans = _load_json_array("res://data/game_plans.json")
    super._ready()
    if _normalize_v03_state():
        SaveService.save_game(state)

func new_career(boxer_name: String, trait_id: String = "") -> void:
    super.new_career(boxer_name, trait_id)
    var identity := _pick_identity()
    _apply_identity(identity)
    state["selected_game_plan"] = ""
    SaveService.save_game(state)

func select_opponent(opponent: Dictionary) -> void:
    state.selected_opponent = str(opponent.id)
    state["selected_game_plan"] = ""
    state.last_weigh_in = {}
    state.fight_seed = 0
    state.active_fight = {}
    state.phase = "game_plan"
    SaveService.save_game(state)

func select_game_plan(plan_id: String) -> Dictionary:
    if str(state.get("phase", "")) != "game_plan":
        return {"ok": false, "reason": "wrong_phase"}
    var plan := get_game_plan(plan_id)
    if plan.is_empty():
        return {"ok": false, "reason": "unknown_plan"}
    state.selected_game_plan = str(plan.id)
    state.last_weigh_in = _resolve_weigh_in()
    state.fight_seed = rng.randi()
    state.active_fight = {}
    state.phase = "fight"
    SaveService.save_game(state)
    return {"ok": true, "plan": plan}

func get_fight_boxer() -> Dictionary:
    var boxer: Dictionary = super.get_fight_boxer()
    var plan := get_selected_game_plan()
    var global_stats: Dictionary = plan.get("global_stats", {})
    for stat in TRAINABLE_STATS:
        if global_stats.has(stat):
            boxer[stat] = clamp(int(boxer.get(stat, 50)) + int(global_stats[stat]), 1, 100)
    boxer["game_plan"] = plan.duplicate(true)
    return boxer

func get_selected_game_plan() -> Dictionary:
    return get_game_plan(str(state.get("selected_game_plan", "balanced")))

func get_game_plan(plan_id: String) -> Dictionary:
    for plan in game_plans:
        if str(plan.id) == plan_id:
            return plan
    for plan in game_plans:
        if str(plan.id) == "balanced":
            return plan
    return {}

func identity_description() -> String:
    var boxer: Dictionary = state.get("boxer", {})
    return str(boxer.get("identity_description", "상대에 맞춰 스타일을 바꾸는 복서"))

func _begin_next_cycle() -> void:
    state["selected_game_plan"] = ""
    super._begin_next_cycle()

func _pick_identity() -> Dictionary:
    var candidates: Array = []
    for identity in fighter_identities:
        if str(identity.id) != "balanced":
            candidates.append(identity)
    if candidates.is_empty():
        return _identity_by_id("balanced")
    return candidates[rng.randi_range(0, candidates.size() - 1)]

func _identity_by_id(identity_id: String) -> Dictionary:
    for identity in fighter_identities:
        if str(identity.id) == identity_id:
            return identity
    return {}

func _apply_identity(identity: Dictionary, apply_stats: bool = true) -> void:
    if identity.is_empty() or state.is_empty():
        return
    var boxer: Dictionary = state.boxer
    boxer["identity_id"] = str(identity.get("id", "balanced"))
    boxer["identity_name"] = str(identity.get("name", "균형형"))
    boxer["identity_description"] = str(identity.get("description", ""))
    boxer["identity_signature"] = str(identity.get("signature", ""))
    if apply_stats:
        var bonuses: Dictionary = identity.get("stat_bonus", {})
        for stat in TRAINABLE_STATS:
            if bonuses.has(stat):
                boxer[stat] = clamp(int(boxer.get(stat, 50)) + int(bonuses[stat]), 1, 100)

func _normalize_v03_state() -> bool:
    if state.is_empty():
        return false
    var changed := false
    if not state.has("selected_game_plan"):
        state["selected_game_plan"] = "balanced" if str(state.get("phase", "")) == "fight" else ""
        changed = true
    var boxer: Dictionary = state.boxer
    if not boxer.has("identity_id"):
        _apply_identity(_identity_by_id("balanced"), false)
        changed = true
    if str(state.get("phase", "")) == "game_plan" and str(state.get("selected_opponent", "")).is_empty():
        state.phase = "fight_offer"
        changed = true
    return changed
