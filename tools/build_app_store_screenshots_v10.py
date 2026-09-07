#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "visual-captures" / "v1.0-font"
OUT_DIR = ROOT / "assets" / "release" / "screenshots" / "ko-KR" / "iphone-6.9"

TARGET_W = 1260
TARGET_H = 2736
SOURCE_W = 430
SOURCE_H = 932

# App Store order is commercial, not chronological: lead with the strongest actual fight image,
# then show fight presentation and the career-management depth behind it.
OUTPUTS = [
    ("01_fight_impact.png", "07_fight_after_jab.png"),
    ("02_fight_opening.png", "06_fight_opening.png"),
    ("03_camp.png", "02_camp.png"),
    ("04_scouting_game_plan.png", "04_scouting_game_plan.png"),
    ("05_fight_offer.png", "03_fight_offer.png"),
    ("06_weigh_in.png", "05_weigh_in.png"),
    ("07_result.png", "08_result.png"),
    ("08_title.png", "01_title.png"),
]


def upscale_store_portrait(src: Image.Image) -> Image.Image:
    if src.size != (SOURCE_W, SOURCE_H):
        raise SystemExit(f"unexpected source size: {src.size}, expected {(SOURCE_W, SOURCE_H)}")

    # Apple 6.9-inch portrait 1260x2736 is almost exactly the 430x932 product aspect.
    # Scale by height and center-crop only the ~2 px excess width at target resolution.
    src = src.convert("RGB")
    scale = TARGET_H / SOURCE_H
    scaled_w = int(round(SOURCE_W * scale))
    scaled = src.resize((scaled_w, TARGET_H), Image.Resampling.LANCZOS)
    if scaled_w < TARGET_W:
        raise SystemExit(f"scaled screenshot too narrow: {scaled_w}")
    left = (scaled_w - TARGET_W) // 2
    return scaled.crop((left, 0, left + TARGET_W, TARGET_H))


def main() -> int:
    missing = [source for _, source in OUTPUTS if not (SOURCE_DIR / source).exists()]
    if missing:
        raise SystemExit(f"missing actual Godot captures: {', '.join(missing)}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("*.png"):
        old.unlink()

    for output_name, source_name in OUTPUTS:
        source = Image.open(SOURCE_DIR / source_name)
        final = upscale_store_portrait(source)
        final.save(OUT_DIR / output_name, format="PNG", optimize=True)
        print(f"built {output_name} <- {source_name}: {final.size[0]}x{final.size[1]} RGB")

    print(f"built {len(OUTPUTS)} commercially ordered App Store screenshots from actual 430x932 Godot renders")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
