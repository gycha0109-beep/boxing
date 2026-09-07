#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
required = [
    "project.godot", "scenes/Main.tscn", "scripts/main.gd", "scripts/main_v05.gd", "scripts/main_v06.gd", "scripts/main_v07.gd",
    "scripts/core/game_state.gd", "scripts/core/combat_engine.gd", "scripts/core/save_service.gd",
    "scripts/ui/combat_presentation.gd", "scripts/ui/fight_stage.gd", "scripts/ui/impact_feedback.gd",
    "scripts/ui/fight_fx_director.gd", "scripts/ui/arena_audio.gd", "scripts/ui/safe_area_layout.gd", "scripts/ui/visual_asset_catalog.gd",
    "data/balance.json", "data/camp_actions.json", "data/opponents.json", "data/career_balance.json",
    "data/traits.json", "data/events.json", "data/injuries.json", "data/fighter_identities.json", "data/game_plans.json",
    "tools/sim_combat.py", "tools/simulate_careers.py", "tools/simulate_gameplans.py", "tools/test_gameplans.py",
    "tools/validate_visual_assets_v07.py", "tools/import_visual_assets_v07.ps1",
    "tests/runtime_state_smoke.gd", "tests/v03_gameplan_smoke.gd", "tests/v04_combat_ux_smoke.gd",
    "tests/v04_fight_ui_smoke.gd", "tests/v05_fight_presentation_smoke.gd", "tests/v06_device_polish_smoke.gd",
    "tests/v07_visual_integration_smoke.gd",
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
assert 'res://scripts/main_v07.gd' in scene

main_v05 = (ROOT / "scripts/main_v05.gd").read_text()
assert 'extends "res://scripts/main.gd"' in main_v05
assert "FightStage.new()" in main_v05 and "ImpactFeedback.new()" in main_v05
assert "func _choose_fight_action(" in main_v05

main_v06 = (ROOT / "scripts/main_v06.gd").read_text()
assert 'extends "res://scripts/main_v05.gd"' in main_v06
assert "MIN_TOUCH_TARGET := 56.0" in main_v06
assert "SafeAreaLayout.current_insets" in main_v06
assert "MainLoop.NOTIFICATION_APPLICATION_PAUSED" in main_v06
assert "MainLoop.NOTIFICATION_APPLICATION_RESUMED" in main_v06
assert "FightFxDirector.interaction_lock_seconds" in main_v06
assert "ArenaAudio.new()" in main_v06 and "FightFxDirector.new()" in main_v06

main_v07 = (ROOT / "scripts/main_v07.gd").read_text()
assert 'extends "res://scripts/main_v06.gd"' in main_v07
assert "VisualAssetCatalog.portrait_texture" in main_v07
assert "func _render_offers()" in main_v07 and "func _render_game_plan()" in main_v07

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
assert "VisualAssetCatalog.fighter_texture" in stage
assert "VisualAssetCatalog.arena_texture" in stage
assert "VisualAssetCatalog.fx_texture" in stage
assert "_draw_fighter_asset_or_fallback" in stage

catalog = (ROOT / "scripts/ui/visual_asset_catalog.gd").read_text()
assert "class_name VisualAssetCatalog" in catalog
assert 'ROOT := "res://assets/visual/v0.7"' in catalog
assert "fighter_path" in catalog and "portrait_path" in catalog and "arena_path" in catalog and "fx_path" in catalog
assert "missing_required_paths" in catalog and "asset_pack_available" in catalog

impact = (ROOT / "scripts/ui/impact_feedback.gd").read_text()
assert "class_name ImpactFeedback" in impact
assert "AudioStreamGenerator" in impact and "Input.vibrate_handheld" in impact
assert "haptic_amplitude" in impact and "hit_stop_seconds" in impact and "shake_strength" in impact
assert "sfx_cue_for_exchange" in impact and '"body_hit"' in impact and '"head_crack"' in impact

fx = (ROOT / "scripts/ui/fight_fx_director.gd").read_text()
assert "class_name FightFxDirector" in fx
assert "PROCESS_MODE_DISABLED" in fx and "create_timer" in fx
assert "tween_method" in fx and "shake_duration_seconds" in fx

arena = (ROOT / "scripts/ui/arena_audio.gd").read_text()
assert "class_name ArenaAudio" in arena
assert '"round_bell"' in arena and '"final_bell"' in arena and '"corner_call"' in arena
assert "crowd_active" in arena and "AudioStreamGenerator" in arena

safe = (ROOT / "scripts/ui/safe_area_layout.gd").read_text()
assert "class_name SafeAreaLayout" in safe
assert "DisplayServer.get_display_safe_area()" in safe
assert "compute_insets" in safe

save = (ROOT / "scripts/core/save_service.gd").read_text()
assert "SCHEMA_VERSION := 2" in save and "_load_legacy_v1" in save
print("project_sanity: PASS")
