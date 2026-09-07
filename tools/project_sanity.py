#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
required = [
    "project.godot", "scenes/Main.tscn", "scripts/main.gd", "scripts/main_v05.gd",
    "scripts/core/game_state.gd", "scripts/core/combat_engine.gd", "scripts/core/save_service.gd",
    "scripts/ui/combat_presentation.gd", "scripts/ui/fight_stage.gd", "scripts/ui/impact_feedback.gd",
    "data/balance.json", "data/camp_actions.json", "data/opponents.json", "data/career_balance.json",
    "data/traits.json", "data/events.json", "data/injuries.json", "data/fighter_identities.json", "data/game_plans.json",
    "tools/sim_combat.py", "tools/simulate_careers.py", "tools/simulate_gameplans.py", "tools/test_gameplans.py",
    "tests/runtime_state_smoke.gd", "tests/v03_gameplan_smoke.gd", "tests/v04_combat_ux_smoke.gd",
    "tests/v04_fight_ui_smoke.gd", "tests/v05_fight_presentation_smoke.gd",
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
assert 'res://scripts/main_v05.gd' in scene
main_v05 = (ROOT / "scripts/main_v05.gd").read_text()
assert 'extends "res://scripts/main.gd"' in main_v05
assert "FightStage.new()" in main_v05 and "ImpactFeedback.new()" in main_v05
assert "func _choose_fight_action(" in main_v05

for name in ["balance.json","camp_actions.json","opponents.json","career_balance.json","traits.json","events.json","injuries.json","fighter_identities.json","game_plans.json"]:
    json.loads((ROOT / "data" / name).read_text())

combat = (ROOT / "scripts/core/combat_engine.gd").read_text()
for action in ["jab","power","body","guard","counter"]:
    assert f'"{action}"' in combat
assert "func export_state()" in combat and "func restore(" in combat
assert "tendencies" in combat and "action_modifiers" in combat and "requires_target_actions" in combat
assert "reactive_window" in combat
assert 'if reactive_window and action_id == "counter"' in combat
assert "COMMITTED_ATTACKS" in combat
assert 'player_action == "counter" and opponent_action in COMMITTED_ATTACKS' in combat
assert 'opponent_action == "counter" and player_action in COMMITTED_ATTACKS' in combat
assert "miss_read_stats" in combat
assert 'source = modifiers.get("miss_read_stats", {})' in combat
assert "initiative_bias" not in combat

sim_combat = (ROOT / "tools/sim_combat.py").read_text()
assert "reactive_window" in sim_combat
assert 'if reactive_window and action_id == "counter"' in sim_combat
assert "COMMITTED_ATTACKS" in sim_combat
assert 'pa == "counter" and oa in COMMITTED_ATTACKS' in sim_combat
assert 'oa == "counter" and pa in COMMITTED_ATTACKS' in sim_combat
assert "miss_read_stats" in sim_combat
assert 'source = mods.get("miss_read_stats", {})' in sim_combat
assert "initiative_bias" not in sim_combat

state = (ROOT / "scripts/core/game_state.gd").read_text()
assert 'state.phase = "game_plan"' in state
assert "func select_game_plan(" in state
assert "fighter_identities" in state and "game_plans" in state and "selected_game_plan" in state

main = (ROOT / "scripts/main.gd").read_text()
assert '"game_plan": _render_game_plan()' in main
assert "상대 스카우팅" in main and "행동 경향" in main

stage = (ROOT / "scripts/ui/fight_stage.gd").read_text()
assert "class_name FightStage" in stage
assert "func play_exchange(" in stage
assert 'player_pose = "down"' in stage and 'opponent_pose = "down"' in stage

impact = (ROOT / "scripts/ui/impact_feedback.gd").read_text()
assert "class_name ImpactFeedback" in impact
assert "AudioStreamGenerator" in impact and "Input.vibrate_handheld" in impact
assert '"knockdown"' in impact and '"counter"' in impact

save = (ROOT / "scripts/core/save_service.gd").read_text()
assert "SCHEMA_VERSION := 2" in save and "_load_legacy_v1" in save
print("project_sanity: PASS")
