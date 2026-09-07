#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
required = [
    "project.godot", "scenes/Main.tscn", "scripts/main.gd",
    "scripts/core/game_state.gd", "scripts/core/combat_engine.gd", "scripts/core/save_service.gd",
    "data/balance.json", "data/camp_actions.json", "data/opponents.json", "data/career_balance.json",
    "data/traits.json", "data/events.json", "data/injuries.json", "data/fighter_identities.json", "data/game_plans.json",
    "tools/sim_combat.py", "tools/simulate_careers.py", "tools/simulate_gameplans.py", "tools/test_gameplans.py",
    "tests/runtime_state_smoke.gd", "tests/v03_gameplan_smoke.gd",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    raise SystemExit(f"missing required files: {missing}")

for obsolete in ["scripts/main_v03.gd", "scripts/core/game_state_v03.gd", "scripts/core/combat_engine_v03.gd"]:
    assert not (ROOT / obsolete).exists(), f"obsolete subclass remains: {obsolete}"

project = (ROOT / "project.godot").read_text()
assert 'run/main_scene="res://scenes/Main.tscn"' in project
assert 'GameState="*res://scripts/core/game_state.gd"' in project
scene = (ROOT / "scenes/Main.tscn").read_text()
assert 'res://scripts/main.gd' in scene

for name in ["balance.json","camp_actions.json","opponents.json","career_balance.json","traits.json","events.json","injuries.json","fighter_identities.json","game_plans.json"]:
    json.loads((ROOT / "data" / name).read_text())

combat = (ROOT / "scripts/core/combat_engine.gd").read_text()
for action in ["jab","power","body","guard","counter"]:
    assert f'"{action}"' in combat
assert "func export_state()" in combat and "func restore(" in combat
assert "tendencies" in combat and "action_modifiers" in combat and "requires_target_actions" in combat
assert "reactive_window" in combat
assert 'if reactive_window and action_id == "counter"' in combat
assert "not reactive_window or not target_action in required" in combat

sim_combat = (ROOT / "tools/sim_combat.py").read_text()
assert "reactive_window" in sim_combat
assert 'if reactive_window and action_id == "counter"' in sim_combat
assert "not reactive_window or target_action not in required" in sim_combat

state = (ROOT / "scripts/core/game_state.gd").read_text()
assert 'state.phase = "game_plan"' in state
assert "func select_game_plan(" in state
assert "fighter_identities" in state and "game_plans" in state and "selected_game_plan" in state

main = (ROOT / "scripts/main.gd").read_text()
assert '"game_plan": _render_game_plan()' in main
assert "상대 스카우팅" in main and "행동 경향" in main

save = (ROOT / "scripts/core/save_service.gd").read_text()
assert "SCHEMA_VERSION := 2" in save and "_load_legacy_v1" in save
print("project_sanity: PASS")
