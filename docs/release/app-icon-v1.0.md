# App Icon v1.0

## Goal

Freeze a single sellable App Store identity for Twelve Count without changing gameplay or the accepted release UI.

## Visual direction

The icon must read as **Twelve Count / premium boxing career** before it reads as a generic mobile game.

Locked direction:

- one boxer only
- close 3/4 head-and-upper-torso composition
- high boxing guard with red gloves
- stern, focused expression
- dark navy / near-black fight-night background
- warm gold rim light
- restrained red accent from the gloves
- semi-realistic 2D boxing-poster illustration consistent with the in-game art language
- strong central silhouette and large value masses that survive downscaling

Do not use:

- title lettering or small text
- UI chrome, HUD, badges, ranks, or stats
- multiple fighters
- unrelated image fragments
- extra limbs or duplicated gloves
- transparent background
- pre-rounded corners
- photographic stock imagery
- POV/pixel-art language

## Source authority

Final master path:

`assets/release/icon/app_store_1024.png`

Requirements:

- exactly 1024×1024 PNG
- fully opaque at every pixel
- square source with artwork extending naturally into all four corners
- no baked rounded mask
- key face/glove silhouette remains inside a conservative safe region so iOS masking does not remove essential identity

## iPhone export slots

All release slots are explicit repository assets derived from the approved master:

| Godot slot | Repository path | Pixels |
| --- | --- | ---: |
| App Store | `assets/release/icon/app_store_1024.png` | 1024 |
| iPhone | `assets/release/icon/iphone_180.png` | 180 |
| iPhone | `assets/release/icon/iphone_120.png` | 120 |
| Notification | `assets/release/icon/notification_60.png` | 60 |
| Notification | `assets/release/icon/notification_40.png` | 40 |
| Settings | `assets/release/icon/settings_87.png` | 87 |
| Settings | `assets/release/icon/settings_58.png` | 58 |
| Spotlight | `assets/release/icon/spotlight_80.png` | 80 |
| Spotlight | `assets/release/icon/spotlight_40.png` | 40 |

The smaller files must be resized from the accepted 1024 master; they are not independent redesigns.

## Automated acceptance

`python3 tools/validate_app_icon_v10.py`

The validator must reject:

- missing slot wiring in `export_presets.cfg`
- missing files
- non-PNG files
- wrong dimensions
- indexed/unsupported PNG encodings
- `tRNS` transparency
- any RGBA pixel with alpha below 255

Automated checks do **not** establish visual quality or prove that the source has no artistically baked rounded rectangle. Those remain direct visual-review gates.

## Direct visual acceptance

Inspect the real master plus downscaled 180, 120, 60, and 40 pixel outputs.

PASS requires all of the following:

- immediately recognizable boxer / boxing-guard silhouette
- face and red gloves remain legible at 60px
- still distinguishable from a generic dark square at 40px
- no accidental text-like noise
- no aliasing halo or transparency fringe
- no clipped face, glove, chin, or shoulder caused by source framing
- no extra limb, duplicated glove, unrelated fragment, or generation residue
- no baked rounded corners
- consistent premium fight-night palette with the actual product

If the 1024 image looks attractive but the 60/40px versions collapse into noise, the icon is **FAIL**.

## Release boundary

App Icon v1.0 changes only release identity assets and export wiring. It must not alter gameplay, balance, combat presentation, first-five-minutes flow, or the accepted 430×932 product UI.
