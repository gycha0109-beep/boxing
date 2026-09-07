# Product Spec v0.7 — Commercial Visual Integration

## Goal

v0.7 turns the deterministic boxing/career runtime into a mobile portrait presentation that can be judged as a coherent commercial vertical slice rather than a procedural prototype.

The authoritative runtime for this release line is Godot 4.7.2 stable. The primary visual verification viewport is 430×932 portrait.

## Scope

### Fighter presentation

- 40 fighter pose PNGs are mapped into runtime: 8 player poses and 8 poses for each of swarmer, out-boxer, slugger, and counter opponents.
- Runtime drawing uses the visible alpha bounds of each sprite rather than the full transparent 512×512 source canvas so different source padding does not create false scale differences.
- Player and opponent are staged as a close 3/4 ringside view with readable attack contact, recoil, hurt, guard, and knockdown states.
- Disconnected generative debris is not permitted in a shippable pose.
- A standing pose must show a readable boxer silhouette rather than a torso-only or lower-body-cropped source frame.

### Deterministic asset remediation

The source generative pack contained debris, gear drift, and irrecoverable crop failures. `tools/clean_fighter_assets_v071.py` is the reproducible remediation authority.

- The dominant connected boxer component is retained and distant debris is removed.
- Swarmer gear drift is corrected deterministically.
- Out-boxer idle uses its canonical clean guard silhouette where the original idle identity drifted.
- Slugger poses use the corresponding clean player choreography with a widened silhouette when the original slugger source is materially cropped.
- Counter poses use the corresponding clean out-boxer choreography with deterministic purple gear conversion and a lean silhouette when the original counter source is materially cropped.
- Re-running the cleanup tool must be canonical/idempotent.

These substitutions prioritize readable gameplay state and deterministic build output over preserving visibly corrupted generated pixels.

### Korean UI and mobile layout

- UI text uses a `SystemFont` fallback chain headed by Apple SD Gothic Neo, Malgun Gothic, and Noto Sans CJK KR/Noto Sans KR, with system fallback enabled.
- No font binary is bundled solely for this v0.7 gate.
- Camp, Fight Offers, Game Plan, and Fight must render Korean text without missing-glyph boxes on a supported system containing a matching Korean font.
- The primary vertical scroll area is vertical-only for this mobile presentation. Long Camp and Game Plan content must wrap into cards rather than increase the content minimum width.
- Long selectable content uses wrapped labels plus short action buttons instead of using an unwrapped button label as the information container.

## Visual contract

At 430×932:

1. No fighter pose contains visible disconnected limbs, scan-line fragments, or unrelated body pieces.
2. All four opponent styles remain distinguishable by palette/silhouette and all 8 mapped pose states are readable.
3. Slugger and Counter standing poses include readable lower-body/foot placement rather than the previously cropped source frames.
4. Korean UI glyphs render correctly.
5. Camp, Fight Offers, Game Plan, and Fight do not require horizontal scrolling and do not clip essential copy at the right edge.
6. Fight framing keeps both boxers on the same apparent ring plane and close enough that jab/power exchanges read as contact rather than disconnected animation.

## Verification boundary

Automated asset validation and headless smoke tests are necessary but not sufficient. v0.7 release approval additionally requires direct inspection of actual Godot 4.7.2 screenshots captured at 430×932:

- 4 opponent styles × 8 poses = 32 fight-stage captures.
- 6 integrated flow captures: Camp, Fight Offers, Game Plan, Fight opening, jab contact, and jab recovery.

A CI status alone cannot substitute for direct screenshot inspection.
