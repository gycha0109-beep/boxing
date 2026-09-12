#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

required = [
    "project.godot", "scenes/Main.tscn",
    "scripts/main.gd", "scripts/main_v05.gd", "scripts/main_v06.gd", "scripts/main_v07.gd", "scripts/main_v08.gd", "scripts/main_v10.gd", "scripts/main_v12.gd", "scripts/main_v13.gd", "scripts/main_v14.gd", "scripts/main_v15.gd", "scripts/main_v16.gd", "scripts/main_v17.gd", "scripts/main_v18.gd", "scripts/main_v18_release_base.gd", "scripts/main_v18_release.gd",
    "scripts/core/game_state.gd", "scripts/core/game_state_v12.gd", "scripts/core/game_state_v14.gd", "scripts/core/game_state_v15.gd", "scripts/core/combat_engine.gd", "scripts/core/save_service.gd", "scripts/core/legacy_service.gd",
    "scripts/ui/combat_presentation.gd", "scripts/ui/fight_stage.gd", "scripts/ui/impact_feedback.gd", "scripts/ui/fight_fx_director.gd", "scripts/ui/arena_audio.gd", "scripts/ui/music_director.gd", "scripts/ui/safe_area_layout.gd", "scripts/ui/visual_asset_catalog.gd",
    "scripts/ui/v18_assets/hero_player_00.gd", "scripts/ui/v18_assets/hero_player_01.gd", "scripts/ui/v18_assets/training_atlas_00.gd", "scripts/ui/v18_assets/training_atlas_01.gd", "scripts/ui/v18_assets/opponent_atlas_00.gd", "scripts/ui/v18_assets/opponent_atlas_01.gd", "scripts/ui/v18_assets/fight_ring_scene_00.gd", "scripts/ui/v18_assets/fight_ring_scene_01.gd", "scripts/ui/v18_assets/fight_ring_scene_02.gd",
    "data/balance.json", "data/camp_actions.json", "data/opponents.json", "data/career_balance.json", "data/traits.json", "data/events.json", "data/injuries.json", "data/fighter_identities.json", "data/game_plans.json", "data/legacy_definitions.json", "data/fight_preparations.json", "data/equipment.json",
    "tools/sim_combat.py", "tools/simulate_careers.py", "tools/simulate_gameplans.py", "tools/test_gameplans.py", "tools/validate_visual_assets_v07.py", "tools/validate_release_font_v10.py", "tools/import_visual_assets_v07.ps1",
    "tests/runtime_state_smoke.gd", "tests/legacy_retirement_smoke.gd", "tests/legacy_slot_effect_smoke.gd", "tests/pre_fight_preparation_smoke.gd", "tests/boxer_creation_ladder_smoke.gd", "tests/equipment_economy_smoke.gd", "tests/audio_music_smoke.gd", "tests/v03_gameplan_smoke.gd", "tests/v04_combat_ux_smoke.gd", "tests/v04_fight_ui_smoke.gd", "tests/v05_fight_presentation_smoke.gd", "tests/v06_device_polish_smoke.gd", "tests/v07_visual_integration_smoke.gd", "tests/v08_first_five_minutes_smoke.gd", "tests/v10_release_font_smoke.gd", "tests/mobile_scroll_back_smoke.gd", "tests/fight_fixed_hud_smoke.gd",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    raise SystemExit(f"missing required files: {missing}")

for obsolete in ["scripts/main_v03.gd", "scripts/core/game_state_v03.gd", "scripts/core/combat_engine_v03.gd"]:
    assert not (ROOT / obsolete).exists(), f"obsolete subclass remains: {obsolete}"

project = (ROOT / "project.godot").read_text()
scene = (ROOT / "scenes/Main.tscn").read_text()
assert 'run/main_scene="res://scenes/Main.tscn"' in project
assert 'GameState="*res://scripts/core/game_state_v15.gd"' in project
assert 'res://scripts/main_v18_release.gd' in scene

main_chain = {
    "scripts/main_v05.gd": 'extends "res://scripts/main.gd"',
    "scripts/main_v06.gd": 'extends "res://scripts/main_v05.gd"',
    "scripts/main_v07.gd": 'extends "res://scripts/main_v06.gd"',
    "scripts/main_v08.gd": 'extends "res://scripts/main_v07.gd"',
    "scripts/main_v10.gd": 'extends "res://scripts/main_v08.gd"',
    "scripts/main_v12.gd": 'extends "res://scripts/main_v10.gd"',
    "scripts/main_v13.gd": 'extends "res://scripts/main_v12.gd"',
    "scripts/main_v14.gd": 'extends "res://scripts/main_v13.gd"',
    "scripts/main_v15.gd": 'extends "res://scripts/main_v14.gd"',
    "scripts/main_v16.gd": 'extends "res://scripts/main_v15.gd"',
    "scripts/main_v17.gd": 'extends "res://scripts/main_v16.gd"',
    "scripts/main_v18.gd": 'extends "res://scripts/main_v17.gd"',
    "scripts/main_v18_release_base.gd": 'extends "res://scripts/main_v18.gd"',
    "scripts/main_v18_release.gd": 'extends "res://scripts/main_v18_release_base.gd"',
}
for path, marker in main_chain.items():
    assert marker in (ROOT / path).read_text(), f"main inheritance broken: {path}"

main_v13 = (ROOT / "scripts/main_v13.gd").read_text()
for marker in ["func _render_style_select()", "func _render_talent_reveal()", "타고난 재능", "복싱 스타일", "func _render_career_ladder_card()", "func _render_tactical_preparation()", "func _render_condition_preparation()", "영구 스탯은 더 오르지 않습니다", "추가 성장은 없습니다"]:
    assert marker in main_v13

main_v14 = (ROOT / "scripts/main_v14.gd").read_text()
for marker in ["func _render_equipment_shop()", "func _render_equipment_section(", "func _purchase_equipment(", "장비 · 체육관 투자", "장비는 이번 복서의 커리어가 끝나면 리셋됩니다"]:
    assert marker in main_v14
assert "%" not in "".join(line for line in main_v14.splitlines() if "training_percent" in line), "equipment UI should not expose hidden training percentages"

main_v15 = (ROOT / "scripts/main_v15.gd").read_text()
for marker in ["MusicDirector", "func _sync_music_for_phase()", "func _wire_ui_sounds()", "func _choose_fight_action(", "duck(0.72)", "func _notification("]:
    assert marker in main_v15

main_v16 = (ROOT / "scripts/main_v16.gd").read_text()
for marker in ["func _render_camp()", "func _render_offers()", "func _render_game_plan()", "func _render_tactical_preparation()", "func _render_condition_preparation()", "func _render_style_select()", "func _v16_stat_row(", "func _show_stat_help(", "GridContainer", "opponent_portrait_texture_for_name"]:
    assert marker in main_v16

main_v18 = (ROOT / "scripts/main_v18.gd").read_text()
for marker in ["func _v18_decode_chunks(", "append_array(decoded)", "func _v18_photo(", "func _v18_training_texture(", "func _v18_opponent_photo(", "func _render_fight(", '"RING"', '"다음 행동"', 'identity_portrait_texture', 'FightStage.new()']:
    assert marker in main_v18
assert 'return "Marcus Bell"' not in main_v18, "UI must not rename a data-defined opponent"
assert 'stage_photo' not in main_v18, "live combat must not use a baked fighter photo"
for asset_marker in ["V18_HERO_0", "V18_TRAINING_0", "V18_OPPONENT_0", "V18_RING_0"]:
    assert asset_marker in main_v18

main_v18_release_base = (ROOT / "scripts/main_v18_release_base.gd").read_text()
for marker in ["func _v17_top_bar()", "func _v18_release_touch_targets(", "56.0"]:
    assert marker in main_v18_release_base

main_v18_release = (ROOT / "scripts/main_v18_release.gd").read_text()
for marker in ["func _render_tactical_preparation()", "func _render_fight(", "func _v19_disable_legacy_bitmap_fx()", "func _v17_top_bar()", '"V19BottomNav"', '"V19FightActions"', '"상대 읽기"', '"코너 조언"']:
    assert marker in main_v18_release, f"v19 redesign marker missing: {marker}"
assert '"OPPONENT READ"' not in main_v18_release, "active fight UI regressed to the legacy English read card"
assert '"★ PLAN"' not in main_v18_release, "active fight buttons regressed to legacy PLAN copy"

visual_catalog = (ROOT / "scripts/ui/visual_asset_catalog.gd").read_text()
for marker in ["VISUAL_PROFILE_BY_NAME", "VISUAL_STYLE_BY_PROFILE", "opponent_visual_profile_for_name", "opponent_visual_style_for_name", "opponent_portrait_texture_for_name", '"박태호": "korean"', '"에번 브룩스": "black"']:
    assert marker in visual_catalog

music = (ROOT / "scripts/ui/music_director.gd").read_text()
for marker in ["class_name MusicDirector", "MUSIC_VOLUME_DB", "UI_VOLUME_DB", "func set_mode(", "func play_ui(", "func duck(", "func track_profile(", "func mode_for_phase(", '"fight_week"', '"legacy"']:
    assert marker in music

state_v12 = (ROOT / "scripts/core/game_state_v12.gd").read_text()
assert 'extends "res://scripts/core/game_state.gd"' in state_v12
assert "Legacy.observe_career_peak" in state_v12 and "Legacy.apply_camp_growth_bonus" in state_v12
assert "func select_tactical_preparation(" in state_v12 and "func select_condition_preparation(" in state_v12
assert "func start_next_generation()" in state_v12

state_v14 = (ROOT / "scripts/core/game_state_v14.gd").read_text()
assert 'extends "res://scripts/core/game_state_v12.gd"' in state_v14
for marker in ["func begin_boxer_creation()", "func select_boxing_style(", "func talent_definition()", "WORLD_TITLE_MIN_FIGHTS := 16", "WORLD_TITLE_MIN_WINS := 12", "func world_title_ready()", "func career_ladder_stage()", "func get_fight_offers("]:
    assert marker in state_v14

state_v15 = (ROOT / "scripts/core/game_state_v15.gd").read_text()
assert 'extends "res://scripts/core/game_state_v14.gd"' in state_v15
for marker in ["STARTING_BASE_STAT := 44", "EQUIPMENT_PATH", "func purchase_equipment(", "func next_equipment_upgrade(", "func gym_training_percent(", "func apply_camp_action(", 'career_state["equipment_state"]']:
    assert marker in state_v15

for name in ["balance.json","camp_actions.json","opponents.json","career_balance.json","traits.json","events.json","injuries.json","fighter_identities.json","game_plans.json","legacy_definitions.json","fight_preparations.json","equipment.json"]:
    json.loads((ROOT / "data" / name).read_text())

styles = json.loads((ROOT / "data/fighter_identities.json").read_text())
for style in styles:
    assert sum(int(style.get("stat_bonus", {}).get(stat, 0)) for stat in ["power","speed","technique","defense","conditioning"]) == 0, f"style is not zero-sum: {style['id']}"

equipment = json.loads((ROOT / "data/equipment.json").read_text())
assert set(equipment) == {"personal", "gym"}
assert len(equipment["personal"]) == 9 and len(equipment["gym"]) == 12

preparations = json.loads((ROOT / "data/fight_preparations.json").read_text())
assert len(preparations.get("tactical", [])) >= 4
assert len(preparations.get("condition", [])) >= 3

combat = (ROOT / "scripts/core/combat_engine.gd").read_text()
for action in ["jab","power","body","guard","counter"]:
    assert f'"{action}"' in combat
for marker in ["func export_state()", "func restore(", "tendencies", "action_modifiers", "requires_target_actions", "reactive_window", "COMMITTED_ATTACKS", "miss_read_stats"]:
    assert marker in combat
assert "initiative_bias" not in combat

sim_combat = (ROOT / "tools/sim_combat.py").read_text()
for marker in ["reactive_window", "COMMITTED_ATTACKS", "miss_read_stats"]:
    assert marker in sim_combat
assert "initiative_bias" not in sim_combat

legacy = (ROOT / "scripts/core/legacy_service.gd").read_text()
for marker in ["class_name LegacyService", "career_high_points", "func replace_retirement_legacy(", "func abandon_retirement_legacy(", "func effect_value(", "DIMINISHING_FACTOR", "legacy_status", '"definition_id"', '"source_generation"']:
    assert marker in legacy

release_shell = (ROOT / "scripts/main_v10.gd").read_text()
assert 'res://assets/fonts/NotoSansKR-VF.ttf' in release_shell
assert "allow_system_fallback = false" in release_shell

save = (ROOT / "scripts/core/save_service.gd").read_text()
assert "SCHEMA_VERSION := 3" in save
assert "PREVIOUS_SCHEMA_VERSION := 2" in save and "_load_previous_v2" in save and "_load_legacy_v1" in save

print("project_sanity: PASS")
