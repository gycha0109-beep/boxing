#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIONS = {"jab", "power", "body", "guard", "counter"}
STATS = {"power", "speed", "technique", "defense", "conditioning"}

identities = json.loads((ROOT / "data/fighter_identities.json").read_text())
plans = json.loads((ROOT / "data/game_plans.json").read_text())
opponents = json.loads((ROOT / "data/opponents.json").read_text())

identity_ids = {item["id"] for item in identities}
plan_ids = {item["id"] for item in plans}
assert len(identity_ids) == len(identities), "duplicate fighter identity id"
assert len(plan_ids) == len(plans), "duplicate game plan id"
assert "balanced" in identity_ids, "balanced identity fallback missing"
assert "balanced" in plan_ids, "balanced game-plan fallback missing"
assert len(identity_ids - {"balanced"}) >= 4, "need at least four meaningful fighter identities"
assert len(plan_ids - {"balanced"}) >= 4, "need at least four meaningful game plans"

for identity in identities:
    assert identity.get("name") and identity.get("description") and identity.get("signature")
    for stat, delta in identity.get("stat_bonus", {}).items():
        assert stat in STATS, f"unknown identity stat {stat}"
        assert -8 <= int(delta) <= 8, f"identity bonus too extreme: {identity['id']} {stat}"

for plan in plans:
    assert plan.get("name") and plan.get("description") and plan.get("risk")
    for stat, delta in plan.get("global_stats", {}).items():
        assert stat in STATS, f"unknown global plan stat {stat}"
        assert -8 <= int(delta) <= 8, f"global game-plan bonus too extreme: {plan['id']} {stat}"
    for action_id, modifiers in plan.get("action_modifiers", {}).items():
        assert action_id in ACTIONS, f"unknown action in plan {plan['id']}: {action_id}"
        for stat, delta in modifiers.items():
            assert stat in STATS, f"unknown action modifier stat {stat}"
            assert -10 <= int(delta) <= 10, f"action modifier too extreme: {plan['id']} {action_id} {stat}"
    if plan["id"] != "balanced":
        assert plan.get("global_stats") or plan.get("action_modifiers"), f"plan has no gameplay effect: {plan['id']}"

for opponent in opponents:
    tendencies = opponent.get("tendencies", {})
    assert set(tendencies) == ACTIONS, f"{opponent['id']} tendencies must cover all actions"
    assert all(float(value) >= 0 for value in tendencies.values()), f"negative tendency: {opponent['id']}"
    total = sum(float(value) for value in tendencies.values())
    assert abs(total - 1.0) < 1e-9, f"tendencies must sum to 1.0: {opponent['id']}={total}"
    scouting = opponent.get("scouting", {})
    for field in ["strength", "weakness", "tell"]:
        assert scouting.get(field), f"missing scouting {field}: {opponent['id']}"
    suggested = scouting.get("suggested_plans", [])
    assert len(suggested) >= 2, f"need at least two suggested plans: {opponent['id']}"
    assert all(plan_id in plan_ids and plan_id != "balanced" for plan_id in suggested), f"invalid suggested plan: {opponent['id']}"

print("gameplan-data: PASS")
