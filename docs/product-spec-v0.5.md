# Product Spec v0.5 — Fight Presentation + Impact

Date: 2026-09-07
Branch: `feat/fight-presentation-impact-v0.5`

## Objective

Make the tactical exchange feel like boxing on screen without changing Twelve Count into a real-time action game.

v0.4 proved the observe → choose → feedback loop. v0.5 adds a presentation layer that turns the same deterministic exchange result into visible fighter motion, recoil, knockdown, impact flash, short procedural impact audio, and a mobile haptic pulse.

## Product promise

> The player still makes one tactical choice per exchange, but the result now reads as a boxing moment rather than a spreadsheet update.

## FightStage

`FightStage` is a lightweight procedural 2D ring renderer. It does not own combat state or RNG.

It renders:

- ring floor, ropes, and corner posts
- two stylized boxer silhouettes
- guard stance
- Jab extension
- Power rear-hand commitment
- Body level change
- Counter response posture
- hit recoil
- knockdown/down pose
- opponent-read marker
- impact flash with stronger Counter/KO treatment

The stage reads the existing combat snapshot, telegraph, and structured exchange result only.

## Impact routing

`ImpactFeedback` maps one exchange into a presentation profile:

- `miss`
- `guard`
- `medium`
- `heavy`
- `counter`
- `knockdown`

The profile drives two effects:

1. a short procedural `AudioStreamGenerator` impact cue
2. a mobile `Input.vibrate_handheld` pulse with profile-specific duration

These are functional placeholders, not final commercial sound design or device-tuned haptics.

## Determinism boundary

v0.5 must not change:

- opponent action selection
- telegraph generation
- hit/accuracy/damage formulas
- round scoring
- game-plan effects
- career progression
- save schema

The presentation layer consumes the structured result after `CombatEngine.resolve_exchange()`.

## Runtime flow

`Opponent Read → Player Choice → CombatEngine result → save active fight → ImpactFeedback → FightStage animation → next read`

The already-shown opponent action remains locked by v0.4 save semantics before the player acts.

## Architecture

- `scripts/main.gd` remains the stable career/v0.4 UI baseline.
- `scripts/main_v05.gd` extends it and overrides only the fight rendering/action presentation path.
- `scripts/ui/fight_stage.gd` owns procedural ring/fighter drawing and exchange animation.
- `scripts/ui/impact_feedback.gd` owns presentation-profile mapping, procedural impact audio, and mobile vibration.

This isolates v0.5 presentation work from the combat and career authority layers.

## QA gates

v0.5 cannot merge unless the exact head passes:

1. data validation
2. project architecture sanity
3. career invariants
4. opponent ladder simulation
5. game-plan matchup simulation
6. 10,000-career simulation
7. verified Godot 4.7.2 parse/import
8. main-scene boot
9. save/RNG resume fixture
10. v0.3 game-plan fixture
11. v0.4 telegraph/structured-result fixture
12. v0.4 fight UI fixture
13. v0.5 fight-stage/impact/SFX/haptic runtime fixture

## Explicitly not claimed

v0.5 does not prove release-quality presentation.

Still deferred:

- authored boxer sprites or skeletal animation
- final punch/contact timing
- final sound assets and mixing
- iOS-specific haptic feel on hardware
- screen shake tuned on device
- hit-stop tuned by frame rate/device
- safe-area and touch ergonomics on real iPhone/iPad
- iOS suspend/resume
- Xcode archive and App Store delivery

## Success criterion

A headless runtime must prove that the real Main fight phase creates a FightStage, preserves the locked telegraph contract, resolves a real action, creates a non-idle presentation profile, routes an SFX/haptic profile, and leaves combat state identical to the deterministic engine result.
