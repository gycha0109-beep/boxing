# QA Acceptance v0.5 — Fight Presentation + Impact

Date: 2026-09-07

## Scope

This acceptance contract covers the v0.5 presentation layer only. Combat math, career balance, save schema, and v0.4 telegraph determinism remain authoritative and must regress cleanly.

## Automated gates

### Data / balance

- content JSON validates
- fighter identity/scouting/game-plan data validates
- project structure recognizes `main_v05.gd`, `FightStage`, and `ImpactFeedback`
- career invariants pass
- opponent ladder simulation passes
- representative game-plan matchup simulation passes
- 10,000-career simulation passes

### Godot 4.7.2 runtime

- official Godot archive SHA-256 verifies
- project parses/imports without script/autoload failures
- Main scene boots headlessly
- save backup/recovery/v1 migration/RNG resume fixture passes
- v0.3 identity/scouting/game-plan fixture passes
- v0.4 telegraph/structured-exchange fixture passes
- v0.4 fight UI fixture passes
- v0.5 fight presentation fixture passes

## v0.5 runtime fixture requirements

The real `Main.tscn` must:

1. enter the fight phase through the real `GameState` path
2. render a `FightStage`
3. expose the saved pending telegraph to the stage
4. keep the opponent action locked before input
5. resolve a real player action through `CombatEngine`
6. persist the structured exchange result
7. render a non-idle fight presentation profile
8. create the `ImpactFeedback` router
9. map the same exchange to the same impact profile
10. expose deterministic SFX cue and haptic duration mappings

## Presentation profile assertions

At minimum the fixture separately verifies:

- Counter success → `counter`
- KO event → `knockdown`
- high damage hit → `heavy`
- Counter haptic duration is stronger than a medium hit
- knockdown haptic duration is at least 70 ms

## Release boundary

A green v0.5 CI is **not** evidence that the commercial presentation is finished.

Headless CI cannot validate:

- actual visible animation quality
- clipping/spacing on real iPhone/iPad sizes
- perceived hit-stop or screen shake feel
- speaker/headphone sound quality
- real iOS haptic strength/latency
- touch ergonomics
- 60/120 Hz timing
- suspend/resume lifecycle
- Xcode archive/export

## Merge rule

Only an exact-head green run may be used for merge authority. If the feature head changes after a green run, all prior exact-head evidence is stale and CI must be re-run.

After squash merge, the merged `main` SHA must receive its own successful push-triggered QA run before v0.5 is considered closed.
