# QA Acceptance v0.7 — Commercial Visual Gate

## Required engine and viewport

- Godot: 4.7.2 stable, verified binary.
- Primary release visual viewport: 430×932 portrait.

## Automated gates

The final feature head must pass the repository `QA` workflow with both jobs successful:

- `deterministic-data-and-balance`
- `godot-headless-smoke`

The Godot job must import and boot the project, preserve prior save/combat/presentation tests, and pass the v0.7 visual mapping/fallback smoke test.

## Asset gate

- [ ] Exactly 40 fighter pose PNGs are present under the v0.7 fighter pack.
- [ ] Player, swarmer, out-boxer, slugger, and counter each provide the 8 runtime pose states.
- [ ] Cleanup/substitution generation is deterministic and idempotent.
- [ ] No shippable pose contains visible disconnected generated debris.
- [ ] Standing poses are not torso-only or materially lower-body cropped.
- [ ] Knockdown poses remain visually readable in the ring frame.

## Actual-render visual gate

Directly inspect actual Godot 4.7.2 captures at 430×932. CI success without this inspection is insufficient.

### Full fighter matrix

Capture all 32 opponent combinations:

- swarmer: idle, guard, jab, power, body, counter, hurt, down
- out-boxer: idle, guard, jab, power, body, counter, hurt, down
- slugger: idle, guard, jab, power, body, counter, hurt, down
- counter: idle, guard, jab, power, body, counter, hurt, down

Acceptance:

- [ ] No body fragments or unrelated debris are visible.
- [ ] No essential head, torso, leg, or foot placement is unintentionally clipped by the source asset.
- [ ] Player/opponent scale reads as a shared ring plane.
- [ ] Action poses are distinct enough to communicate the mapped state.

### Integrated mobile flow

Capture:

1. Camp
2. Fight Offers
3. Game Plan
4. Fight opening
5. Jab contact
6. Jab recovery

Acceptance:

- [ ] Korean glyphs render without missing-glyph boxes.
- [ ] No horizontal scrollbar is required in the mobile flow.
- [ ] Camp action information wraps inside the available portrait width.
- [ ] Fight Offer cards stay within the portrait width.
- [ ] Scouting and Game Plan information wraps inside the available portrait width.
- [ ] Fight HUD and ring content remain inside the safe presentation width.
- [ ] Jab contact/recovery reads as a connected exchange.

## Merge gate

Before merge:

1. Re-query `main` and the feature branch.
2. Treat any feature-head change as invalidating previous exact-head CI evidence.
3. Confirm final feature-head QA success.
4. Confirm the latest 38-capture visual artifact was produced from the same product content as the final feature head plus capture-only files.
5. Create the PR only after the above gates are satisfied.
6. Re-check PR exact-head CI before merge.
7. Squash merge only after all required checks and visual evidence remain valid.
8. Re-run/verify QA on merged `main` before declaring v0.7 closed.
