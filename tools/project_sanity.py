#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
required = [
    "project.godot", "scenes/Main.tscn", "scripts/main.gd", "scripts/main_v03.gd",
    "scripts/core/game_state.gd", "scripts/core/game_state_v03.gd",
    "scripts/core/combat_engine.gd", "scripts/core/combat_engine_v03.gd", "scripts/core/save_service.gd",
    "data/balance.json", "data/camp_actions.json", "data/opponents.json", "data/career_balance.json",
    "data/traits.json", "data/events.json", "data/injuries.json", "data/fighter_identities.json", "data/game_plans.json",
    "tools/sim_combat.py", "tools/simulate_careers.py", "tools/test_gameplans.py",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    raise SystemExit(f"missing required files: {missing}")
project = (ROOT / "project.godot").read_text()
assert 'run/main_scene="res://scenes/Main.tscn"' in project
assert 'GameState="*res://scripts/core/game_state_v03.gd"' in project
scene = (ROOT / "scenes/Main.tscn").read_text()
assert 'res://scripts/main_v03.gd' in scene
for name in ["balance.json","camp_actions.json","opponents.json","career_balance.json","traits.json","events.json","injuries.json","fighter_identities.json","game_plans.json"]:
    json.loads((ROOT / "data" / name).read_text())
combat = (ROOT / "scripts/core/combat_engine.gd").read_text()
for action in ["jab","power","body","guard","counter"]:
    assert f'"{action}"' in combat
assert "func export_state()" in combat and "func restore(" in combat
v03_combat = (ROOT / "scripts/core/combat_engine_v03.gd").read_text()
assert "tendencies" in v03_combat and "action_modifiers" in v03_combat
v03_state = (ROOT / "scripts/core/game_state_v03.gd").read_text()
assert 'state.phase = "game_plan"' in v03_state and "func select_game_plan(" in v03_state
save = (ROOT / "scripts/core/save_service.gd").read_text()
assert "SCHEMA_VERSION := 2" in save and "_load_legacy_v1" in save
print("project_sanity: PASS")
