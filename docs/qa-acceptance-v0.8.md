# QA Acceptance v0.8 — First Five Minutes Release Gate

## Required engine and viewport

- Godot: 4.7.2 stable, verified binary.
- Primary release visual viewport: 430×932 portrait.

## Automated gates

The final feature head must pass the repository `QA` workflow with both jobs successful:

- `deterministic-data-and-balance`
- `godot-headless-smoke`

The Godot job must import and boot the project, preserve v0.3–v0.7 regression coverage, and pass `tests/v08_first_five_minutes_smoke.gd`.

The v0.8 smoke must verify the actual flow authority:

- fresh untouched career shows Title/New Career gate.
- starting the career enters first Camp.
- Camp choice enters Fight Offers.
- opponent choice enters Scouting/Game Plan.
- Game Plan selection prepares existing fight state but displays Weigh-in before FightStage.
- acknowledging Weigh-in displays FightStage.
- Result renders official result, career update, and continuation CTA.

## First-five-minutes content gate

- [x] Fresh untouched career no longer boots directly into Camp without a title experience.
- [x] First Camp has debut framing.
- [x] Camp effects use player-facing stat labels rather than raw data keys.
- [x] Fight Offer tiers/styles do not expose underscore-style internal IDs.
- [x] Scouting uses localized style labels.
- [x] Counter-plan explanatory copy does not expose `Power/Body` raw action IDs.
- [x] Weigh-in is a dedicated presentation gate without changing the underlying weigh-in simulation.
- [x] Fight style note uses a product label instead of `swarmer`.
- [x] Result is a dedicated official-result presentation with career progression and continuation CTA.

## Actual-render visual gate

Directly inspect actual Godot 4.7.2 captures at 430×932. CI success without this inspection is insufficient.

Required captures:

1. `v08_01_title.png`
2. `v08_02_camp.png`
3. `v08_03_fight_offers.png`
4. `v08_04_game_plan.png`
5. `v08_05_weigh_in.png`
6. `v08_06_fight_opening.png`
7. `v08_07_jab_contact.png`
8. `v08_08_jab_recovery.png`
9. `v08_09_result.png`

Acceptance:

- [x] Korean glyphs render without missing-glyph boxes.
- [x] No horizontal scrollbar is required in the first-five-minutes flow.
- [x] No essential content is clipped at the right edge.
- [x] Title hero, premise, and `프로 커리어 시작` CTA are visible/readable in portrait.
- [x] First Camp reads as a debut preparation screen and camp effects are localized.
- [x] Fight Offer cards keep portrait, opponent identity, stakes, stats, and CTA inside portrait width.
- [x] Game Plan / Scouting reads as a dossier and does not expose raw style IDs.
- [x] Weigh-in shows both portraits, verdict, limit, plan, and `FIGHT NIGHT 입장` without overflow.
- [x] Fight opening retains v0.7 fighter scale/framing and localized style note.
- [x] Jab contact/recovery remains a visually connected exchange.
- [x] Result presents result, career update, and `커리어 계속` CTA without requiring scroll.

## Accepted visual evidence

Release capture R3:

- product head: `88480c49a0a248286bf5b4b02078022d8a73fc04`
- capture branch: `chore/visual-capture-v08-first-five-r3`
- capture workflow run: `34153800561`
- artifact: `twelve-count-v08-first-five-r3-visuals`
- artifact id: `10030262582`
- generated captures: 9/9
- direct inspection: PASS

The capture branch contains the product head plus capture-only script/workflow files. Documentation-only commits after the product head do not invalidate the visual evidence; any runtime/content change does.

## Merge gate

Before merge:

1. Fresh-query `main`, feature head, and PR state.
2. Treat any runtime/content feature-head change after `88480c49...` as invalidating R3 visual evidence.
3. Confirm final feature-head QA success.
4. Confirm any changes after `88480c49...` are documentation-only.
5. Create the PR only after the above gates remain satisfied.
6. Confirm PR-triggered QA succeeds on the unchanged exact PR head.
7. Re-query PR head, `main`, and mergeability immediately before merge.
8. Squash merge using the expected feature-head SHA.
9. Verify `main` points at the squash commit.
10. Verify merged-main QA succeeds before declaring v0.8 closed.