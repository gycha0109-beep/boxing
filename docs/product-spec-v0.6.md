# Twelve Count v0.6 — Device-Ready Presentation Polish

## Goal

Move the verified v0.5 fight presentation from a headless-functional prototype toward a device-testable premium mobile baseline without changing combat authority or career math.

## Runtime changes

- local hit-stop for medium/heavy/counter/knockdown impacts
- time-based screen shake with profile-specific strength/duration
- target-aware impact audio routing: body, head, block, miss, knockdown
- haptic amplitude as well as duration by impact profile
- procedural arena layer with crowd bed, round bell, final bell, corner cue
- mobile safe-area inset scaling through `DisplayServer.get_display_safe_area()`
- minimum 56 logical-pixel button height enforced at runtime
- fight input lock while impact presentation is playing
- app pause persists active fight/current career immediately
- app resume restores arena audio state and reapplies safe-area/touch layout

## Authority boundary

v0.6 does **not** change:

- CombatEngine RNG
- hit/damage/KO/scoring math
- game-plan modifiers
- opponent tendencies
- save schema
- career progression or economy

Presentation still consumes the already-resolved structured exchange.

## Frame-rate contract

Hit-stop, screen shake, input lock, and existing fight tweens are duration-based in seconds. No v0.6 presentation effect advances by a fixed number of rendered frames. This is the code-level prerequisite for consistent 60/120 Hz behavior, not evidence of physical-device parity.

## Commercial-quality items still open

The following remain release gates and must not be described as complete:

- commercial boxer art / final visual identity
- authored release-quality boxer animation set
- mastered glove/head/body impact audio assets
- mastered crowd, bell, corner and UI audio mix
- physical iPhone haptic feel/tuning
- visible safe-area verification on supported iPhone/iPad hardware
- real touch ergonomics across target device sizes
- real 60 Hz and 120 Hz device timing inspection
- iOS suspend/resume lifecycle on hardware
- signed Xcode archive
- physical-device smoke and TestFlight smoke

The procedural silhouettes and generated audio remain implementation placeholders.
