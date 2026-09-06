# Twelve Count — Boxing Career Roguelite

Commercial prototype for a premium, offline iPhone/iPad boxing career roguelite.

## Current baseline — Full Career Spine v0.2

- Engine target: **Godot 4.7.2 stable / GDScript**
- Orientation: portrait, 430×932 logical viewport
- Business model: paid download; no ads, IAP, runtime AI, account, or server
- Korea launch price hypothesis: **₩4,400**
- Product promise: one boxer, short tactical fights, meaningful trade-offs across training, weight, health, money, opponent risk, and career longevity

## Implemented

1. New career with one of 6 traits
2. Camp choice across training / recovery / weight management
3. Fatigue, health, weight, money and injury pressure
4. Three risk/reward fight offers derived from career tier
5. Weigh-in pass / emergency cut / miss consequences
6. Tactical 3-round fight using Jab / Power / Body / Guard / Counter
7. Injury/stat penalties and trait modifiers applied in combat
8. Ranking progression: Prospect → Regional → National → Continental → World → Title
9. Eight post-fight events
10. Multiple retirement/end conditions including world title victory
11. Autosave after consequential actions
12. Save schema v2 with SHA-256 validation, known-good backup, v1 migration, and in-fight resume state
13. Python opponent and full-career simulation harnesses
14. GitHub Actions QA for data, invariants, ladder simulation, and 10,000-career simulation
15. CI downloads the official Godot 4.7.2 Linux editor, verifies its SHA-256, parses/imports the project headlessly, and boots the main scene

## Current balance evidence

The v0.2 baseline is not final release balance. The current 10,000-career balanced-policy simulation yields approximately:

- World champion: **14.7%**
- Average career length: **29.0 fights**
- Loss-retirement: **80.3%**
- Health-retirement: **4.8%**
- Fight-limit retirement: **0.1%**
- Average final money: **₩3.17M**
- Fights entered while injured: **9.0%**

The first v0.2 simulation produced only 1.6% champions and was rejected as progression-locked. The economy was also reworked after simulation showed money becoming irrelevant.

## Run locally

Install Godot 4.7.2 stable, open `project.godot`, then run the main scene.

```bash
python3 tools/test_data.py
python3 tools/project_sanity.py
python3 tools/test_career_logic.py
python3 tools/simulate_balance.py
python3 tools/simulate_careers.py
```

## Verification boundary

Python/data/simulation checks plus **Godot 4.7.2 headless project parsing and main-scene boot** are automated in CI. Remaining release gates include real touch UX, save-corruption and in-fight force-close fixtures, iOS suspend/resume, safe-area/device layout, Xcode/iOS export, and physical-device smoke. This repository must not be labeled release-ready until those gates are closed.

See `docs/product-spec-v0.2.md` and `docs/qa-acceptance-v0.2.md` for the current product and QA baseline.
