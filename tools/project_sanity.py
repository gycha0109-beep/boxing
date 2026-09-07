#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
required = [
    "project.godot", "scenes/Main.tscn", "scripts/main.gd",
    "scripts/core/game_state.gd", "scripts/core/combat_engine.gd", "scripts/core/save_service.gd",
    "data/balance.json", "data/camp_actions.json", "data/opponents.json", "data/career_balance.json",
    "data/traits.json", "data/events.json", "data/injuries.json",
    "tools/sim_combat.py", "tools/simulate_careers.py",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    raise SystemExit(f"missing required files: {missing}")
project = (ROOT / "project.godot").read_text()
assert 'run/main_scene="res://scenes/Main.tscn"' in project
assert 'GameState="*res://scripts/core/game_state.gd"' in project
for name in ["balance.json","camp_actions.json","opponents.json","career_balance.json","traits.json","events.json","injuries.json"]:
    json.loads((ROOT / "data" / name).read_text())
combat = (ROOT / "scripts/core/combat_engine.gd").read_text()
for action in ["jab","power","body","guard","counter"]:
    assert f'"{action}"' in combat
assert "func export_state()" in combat and "func restore(" in combat
save = (ROOT / "scripts/core/save_service.gd").read_text()
assert "SCHEMA_VERSION := 2" in save and "_load_legacy_v1" in save
print("project_sanity: PASS")
