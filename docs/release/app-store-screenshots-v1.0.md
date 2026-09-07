# App Store Screenshots v1.0

## Goal

Produce the Korean iPhone App Store screenshot package from the actual Twelve Count release flow. No mock gameplay, fake HUD, device frame, or store-only UI is permitted.

## Apple submission target

Current release target: **iPhone 6.9-inch portrait, 1260×2736**.

Package rules:

- 1–10 screenshots are accepted; Twelve Count ships 8.
- PNG output.
- no alpha/transparency.
- iPhone-only release; no iPad screenshot package is required while the export target remains iPhone-only.
- only the highest-resolution required iPhone set is maintained for v1.0; App Store Connect may scale it for smaller iPhone displays.

## Source authority

Every store image must originate from the real Godot release shell at the locked 430×932 viewport:

- capture script: `tests/visual_capture_v10.gd`
- source output: `visual-captures/v1.0-font/*.png`
- release shell: `scripts/main_v10.gd`
- bundled Korean font authority: `assets/fonts/NotoSansKR-VF.ttf`

The package builder may only resize/crop the actual viewport capture to Apple's target aspect. It must not redraw gameplay or replace product content.

## Final commercial order

Repository target directory:

`assets/release/screenshots/ko-KR/iphone-6.9/`

The App Store sequence is intentionally **commercial rather than chronological**. The strongest actual combat image leads, then the package shows the fight presentation and the career-management loop behind it.

1. `01_fight_impact.png` — actual jab impact state
2. `02_fight_opening.png` — Fight Night opening
3. `03_camp.png` — fighter career camp
4. `04_scouting_game_plan.png` — scouting + game plan
5. `05_fight_offer.png` — opponent/fight offer
6. `06_weigh_in.png` — weigh-in presentation
7. `07_result.png` — fight result / career continuation
8. `08_title.png` — title / New Career entry

## Build authority

`python3 tools/build_app_store_screenshots_v10.py`

The builder:

- requires all 8 actual 430×932 Godot captures;
- maps those captures into the fixed commercial order above;
- converts to opaque RGB;
- scales by height using Lanczos;
- center-crops only the tiny excess width necessary to reach 1260×2736;
- adds no marketing text, phone frame, artificial screenshot chrome, or mock content.

## Automated acceptance

`python3 tools/validate_app_store_screenshots_v10.py`

PASS requires:

- exactly 8 canonical PNG files with the fixed commercial filenames;
- each file exactly 1260×2736;
- no RGBA/grayscale-alpha color type;
- no PNG `tRNS` transparency;
- canonical Korean package path.

## Direct visual acceptance

Automation does not establish sellable visual quality. The generated 8-shot contact sheet, `01_fight_impact.png`, and `07_result.png` were inspected directly at the generated target resolution.

PASS requires and the accepted package satisfies:

- no missing Korean glyphs/tofu;
- no clipped buttons/cards/text;
- no interpolation artifact that damages legibility;
- no blank/partially rendered frame;
- no stale development ID or debug text;
- actual boxer/fight assets visible where expected;
- screenshot 1 immediately communicates boxing through actual gameplay;
- the complete set communicates Fight → Career → Opponent/Plan → Weigh-in → Result → Title without inventing store-only gameplay;
- no image contradicts the paid, offline, one-boxer career product boundary.

## Accepted evidence

- commercial-order workflow: `34163264308` — **SUCCESS**
- review artifact: `10033309140` / `twelve-count-app-store-screenshots-v10-ko-6.9`
- generated asset commit: `6153b87c40f5865739d57cb5fd770683ed5bf99f`
- inspected outputs: 8-shot contact sheet + full-size Fight Impact + full-size Result
- direct visual verdict: **PASS**

The workflow commit was authored by `github-actions[bot]`, so the subsequent PR-triggered runs were marked `action_required`. That is a GitHub Actions actor/approval boundary, not a product or screenshot failure. A human-authored follow-up head is required for the final exact-head CI evidence before merge.

## Current status

- source 430×932 release flow: GO
- final App Icon: GO
- final commercial 1260×2736 package: **GO**
- PR merge: HOLD only until human-authored exact-head QA/native/screenshot workflows pass
