# Twelve Count v0.6 — QA Acceptance

## Automated gates

The v0.6 branch must pass all previous deterministic and runtime gates plus `tests/v06_device_polish_smoke.gd`.

### v0.6 smoke must prove

- `Main.tscn` runs `main_v06.gd`
- safe-area scaling math is correct for a representative portrait display/safe rectangle
- rendered buttons are at least 56 logical pixels tall
- app pause notification persists state
- app resume notification is handled and layout/audio state is restored
- target-aware body/head impact cue routing is deterministic
- haptic amplitude ordering increases with impact severity
- hit-stop duration and screen-shake strength increase with impact severity
- a heavy synthetic exchange locally freezes only the fight stage, then resumes it
- screen shake is scheduled with time-based Tween duration
- crowd ambience and opening bell routing initialize
- actual Main fight action creates `FightFxDirector`, registers one presentation event, locks input during presentation, then unlocks by elapsed time

## Regression gates

The following remain required:

- content validation
- identity/scouting/game-plan validation
- project sanity
- career invariants
- opponent ladder simulation
- representative game-plan matchup simulation
- 10,000-career simulation
- Godot parse/import
- main scene boot
- save recovery and deterministic fight resume
- v0.3 identity/scouting/game-plan runtime
- v0.4 telegraph and structured-exchange runtime
- v0.4 actual fight UI runtime
- v0.5 fight-stage / impact routing runtime

## Manual device gates — NOT automated

These stay OPEN until physical-device evidence exists:

- commercial boxer art acceptance
- authored final animation acceptance
- mastered glove/head/body SFX acceptance
- mastered crowd/bell/corner mix acceptance
- iPhone haptic feel and amplitude tuning
- iPhone/iPad safe-area screenshots
- touch ergonomics on target device sizes
- 60 Hz versus 120 Hz visual timing comparison
- iOS suspend/resume on hardware
- signed Xcode archive
- TestFlight install and launch

## Release verdict rule

Automated PASS permits merging the v0.6 implementation. It does **not** permit `RELEASE READY` until the manual device gates above have evidence.
