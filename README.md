# Twelve Count — Boxing Career Roguelite

Commercial prototype for a premium, offline iPhone/iPad boxing career roguelite.

## Current baseline — Combat UX + Telegraph v0.4

- Engine target: **Godot 4.7.2 stable / GDScript**
- Orientation: portrait, 430×932 logical viewport
- Business model: paid download; no ads, IAP, runtime AI, account, or server
- Korea launch price hypothesis: **₩4,400**
- Product promise: one boxer, short tactical fights, meaningful trade-offs across training, weight, health, money, opponent risk, matchup adaptation, and career longevity

## Current player loop

`Camp → Fight Offer → Scouting → Game Plan → Weigh-in → Observe/Read → Tactical Exchange → Fight Result → Event → Next Camp`

The game is intentionally **not** a real-time action boxer. The player prepares one boxer for a career, reads opponent tendencies, selects a bout-specific plan, then chooses Jab / Power / Body / Guard / Counter exchange by exchange.

## Implemented

1. New career with one of 6 traits and 4 meaningful fighter identities
2. Camp choice across training / recovery / weight management
3. Fatigue, health, weight, money and injury pressure
4. Risk/reward fight offers derived from career tier
5. Data-driven scouting for all 12 opponents, including tendencies, strengths, weaknesses and tells
6. Five bout-specific game plans: Balanced / Outside Boxing / Body Breakdown / Pressure / Counter Trap
7. Weigh-in pass / emergency cut / miss consequences
8. Tactical 3-round fight using Jab / Power / Body / Guard / Counter
9. Reactive Counter semantics: committed Power/Body must occur before the counter reaction receives the reactive matchup benefit
10. Counter Trap success/failure feedback, including explicit miss-read penalties
11. Opponent telegraph/read state before every exchange
12. Telegraphed opponent action locked into active-fight save so force-close cannot reroll a cue already shown
13. Structured exchange results exposing initiative, hit/miss/guard, damage, stamina changes, body damage, matchup/read state, KO and round-card data
14. Fight UI with HP/STA gauges, opponent-read card, exchange feedback, body condition, round summary and compact action grid
15. Injury/stat penalties, traits and fighter identity/game-plan modifiers applied in combat
16. Ranking progression: Prospect → Regional → National → Continental → World → Title
17. Eight post-fight events
18. Multiple retirement/end conditions including world title victory
19. Autosave after consequential actions and during active fights
20. Save schema v2 with SHA-256 validation, known-good backup, v1 migration, deterministic RNG resume, and additive v0.3/v0.4 fight state
21. Python opponent, matchup and full-career simulation harnesses
22. GitHub Actions QA for data, invariants, ladder simulation, matchup simulation, and 10,000-career simulation
23. CI downloads the official Godot 4.7.2 Linux editor, verifies its SHA-256, parses/imports the project headlessly, boots the main scene, exercises save/resume, executes the v0.3 matchup flow, validates v0.4 telegraph/structured results, and instantiates the real fight-phase UI

## Current balance evidence

The current v0.3/v0.4 informed-scouting policy is a system baseline, not final release balance. The latest accepted 10,000-career simulation before this documentation change yielded approximately:

- World champion: **22.5%**
- Average career length: **28.90 fights**
- Average wins: **11.55**
- Loss-retirement: **66.1%**
- Health-retirement: **10.9%**
- Fight-limit retirement: **0.5%**
- Average final money: **₩3.58M**
- Fights entered while injured: **9.0%**

Representative matchup simulation currently produces different best plans instead of one universal plan:

- Swarmer representative → Counter Trap
- Out-boxer representative → Outside Boxing
- Slugger representative → Counter Trap
- Counter representative → Body Breakdown

These numbers are automated regression evidence, not a claim that release balance is complete.

## Run locally

Install Godot 4.7.2 stable, open `project.godot`, then run the main scene.

```bash
python3 tools/test_data.py
python3 tools/test_gameplans.py
python3 tools/project_sanity.py
python3 tools/test_career_logic.py
python3 tools/simulate_balance.py
python3 tools/simulate_gameplans.py
python3 tools/simulate_careers.py
```

Godot CI additionally runs:

```bash
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/runtime_state_smoke.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/v03_gameplan_smoke.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/v04_combat_ux_smoke.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/v04_fight_ui_smoke.gd
```

## Verification boundary

Automated CI now proves:

- data and career invariants
- matchup/career simulations
- verified Godot 4.7.2 project parsing
- main-scene boot
- save corruption fallback and v1 migration fixture
- deterministic in-fight RNG resume
- fighter identity/scouting/game-plan runtime
- telegraph locking and JSON resume semantics
- structured combat feedback
- real fight-phase UI instantiation and action consumption under headless Godot

This **does not** prove physical-device polish. Remaining release gates include real iPhone/iPad safe-area layout, touch ergonomics, actual animation/art/SFX/haptic quality, iOS suspend/resume, Xcode/iOS export, App Store archive, and physical-device smoke.

This repository must not be labeled release-ready until those gates are closed.

See:

- `docs/product-spec-v0.3.md`
- `docs/product-spec-v0.4.md`
- `docs/qa-acceptance-v0.2.md`
- `docs/design-reference-gladiator-manager.md`
