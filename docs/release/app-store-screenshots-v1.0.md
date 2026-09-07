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

## Final package order

Repository target directory:

`assets/release/screenshots/ko-KR/iphone-6.9/`

1. `01_title.png` — title / New Career entry
2. `02_camp.png` — fighter career camp
3. `03_fight_offer.png` — opponent/fight offer
4. `04_scouting_game_plan.png` — scouting + game plan
5. `05_weigh_in.png` — weigh-in presentation
6. `06_fight_opening.png` — Fight Night opening
7. `07_fight_after_jab.png` — actual combat impact state
8. `08_result.png` — fight result / career continuation

## Build authority

`python3 tools/build_app_store_screenshots_v10.py`

The builder:

- requires all 8 actual 430×932 Godot captures;
- converts to opaque RGB;
- scales by height using Lanczos;
- center-crops only the tiny excess width necessary to reach 1260×2736;
- adds no marketing text, phone frame, artificial screenshot chrome, or mock content.

## Automated acceptance

`python3 tools/validate_app_store_screenshots_v10.py`

PASS requires:

- exactly 8 canonical PNG files;
- each file exactly 1260×2736;
- no RGBA/grayscale-alpha color type;
- no PNG `tRNS` transparency;
- canonical Korean package path.

## Direct visual acceptance

Automation does not establish sellable visual quality. Inspect the generated 8-shot contact sheet plus Fight Night and Result images at full target resolution.

PASS requires:

- no missing Korean glyphs/tofu;
- no clipped buttons/cards/text;
- no interpolation artifact that damages legibility;
- no blank/partially rendered frame;
- no stale development ID or debug text;
- actual boxer/fight assets visible where expected;
- the eight images tell a coherent Title → Career → Opponent → Plan → Weigh-in → Fight → Impact → Result story;
- no image contradicts the paid, offline, one-boxer career product boundary.

## Status entering implementation

- source 430×932 release flow: GO
- final App Icon: GO
- 1260×2736 generated package: HOLD until actual workflow artifact is directly inspected
