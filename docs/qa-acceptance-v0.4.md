# QA Acceptance v0.4 — Combat UX + Telegraph

Date: 2026-09-07

## Automated acceptance

The v0.4 branch must pass all existing deterministic career/balance checks and all Godot runtime checks on the exact pull-request head.

### Data and simulation

- content JSON validation
- fighter identity/scouting/game-plan validation
- project structure sanity
- career invariants
- opponent ladder simulation
- representative game-plan matchup simulation
- 10,000-career informed-scouting simulation

### Godot runtime

- verified official Godot 4.7.2 stable binary
- project parse/import with script-error log gate
- main-scene boot
- save round-trip and known-good backup recovery
- v1 → v2 migration
- deterministic in-fight RNG resume
- v0.3 fighter identity/scouting/game-plan runtime
- v0.4 telegraph lock and structured exchange runtime
- Counter Trap read-success/read-failure presentation
- Body stamina state presentation
- round-card summary presentation
- real Main scene instantiated in fight phase
- visible ROUND/RING/OPPONENT READ/HP/STA/action controls
- telegraphed opponent action persisted before player input
- rendered locked action consumed by the next player input
- structured exchange result persisted after the input

## Latest pre-document exact-head evidence

Head `40f3b44df6e594d577d37a0ffb6335335aecdef6`, workflow run `34095864816`:

- deterministic-data-and-balance: PASS
- godot-headless-smoke: PASS
- fight-phase UI runtime smoke: PASS
- 10,000-career simulation: PASS

Final PR and merge acceptance must use a later exact-head run after documentation changes.

## Not accepted by headless QA

The following remain manual/device/release gates:

- physical iPhone/iPad visual inspection
- safe-area validation across device classes
- touch target and one-handed ergonomics
- animation timing and impact feel
- SFX and crowd mix
- haptics
- screen shake / flash / hit-stop tuning
- iOS suspend/resume around a displayed telegraph
- Xcode export/archive
- App Store submission assets and metadata
- physical-device smoke from new career through fight result

## Release verdict

Passing this document means **v0.4 system/runtime acceptance**, not commercial release readiness.
