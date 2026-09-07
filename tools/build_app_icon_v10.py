#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PLAYER_GUARD = ROOT / "assets/visual/v0.7/fighters/player/player_base_guard.png"
ARENA = ROOT / "assets/visual/v0.7/arena/arena_title_night.png"
OUT = ROOT / "assets/release/icon"

SLOTS = {
    "app_store_1024.png": 1024,
    "iphone_180.png": 180,
    "iphone_120.png": 120,
    "notification_60.png": 60,
    "notification_40.png": 40,
    "settings_87.png": 87,
    "settings_58.png": 58,
    "spotlight_80.png": 80,
    "spotlight_40.png": 40,
}


def cover(img: Image.Image, size: int) -> Image.Image:
    w, h = img.size
    scale = max(size / w, size / h)
    nw, nh = int(round(w * scale)), int(round(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = max(0, (nw - size) // 2)
    top = max(0, (nh - size) // 2)
    return img.crop((left, top, left + size, top + size))


def upper_guard_subject() -> Image.Image:
    fighter = Image.open(PLAYER_GUARD).convert("RGBA")
    alpha = fighter.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise SystemExit("player guard source has no visible alpha content")

    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top

    # Head + gloves + chest/waist only. This uses icon area for the readable guard silhouette,
    # while leaving conservative space around the face/gloves for Apple's runtime mask.
    upper_bottom = min(bottom, top + int(round(height * 0.54)))
    pad_x = int(round(width * 0.09))
    pad_y = int(round(height * 0.03))
    crop = fighter.crop((
        max(0, left - pad_x),
        max(0, top - pad_y),
        min(fighter.width, right + pad_x),
        min(fighter.height, upper_bottom + pad_y),
    ))

    cw, ch = crop.size
    side = max(cw, ch)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(crop, ((side - cw) // 2, max(0, (side - ch) // 2 - int(side * 0.035))))
    square = square.resize((980, 980), Image.Resampling.LANCZOS)

    rgb = ImageEnhance.Contrast(square.convert("RGB")).enhance(1.10)
    rgb = ImageEnhance.Color(rgb).enhance(1.09)
    graded = rgb.convert("RGBA")
    graded.putalpha(square.getchannel("A"))
    return graded


def build_master() -> Image.Image:
    arena = Image.open(ARENA).convert("RGB")
    arena = cover(arena, 1024).filter(ImageFilter.GaussianBlur(4.0))
    arena = ImageEnhance.Brightness(arena).enhance(0.40)
    arena = ImageEnhance.Color(arena).enhance(0.68)

    navy = Image.new("RGB", (1024, 1024), (6, 14, 24))
    base = Image.blend(arena, navy, 0.36).convert("RGBA")

    subject = upper_guard_subject()
    subject_alpha = subject.getchannel("A")

    halo = subject_alpha.filter(ImageFilter.GaussianBlur(24.0))
    gold = Image.new("RGBA", subject.size, (205, 155, 73, 0))
    gold.putalpha(halo.point(lambda p: int(p * 0.28)))

    pos = ((1024 - subject.width) // 2, 20)
    base.alpha_composite(gold, pos)
    base.alpha_composite(subject, pos)

    # Square opaque vignette only; never bake Apple's rounded mask into the source.
    vignette = Image.new("L", (1024, 1024), 0)
    vp = vignette.load()
    for y in range(1024):
        ny = abs(y - 511.5) / 511.5
        for x in range(1024):
            nx = abs(x - 511.5) / 511.5
            edge = max(nx, ny)
            vp[x, y] = int(max(0.0, (edge - 0.58) / 0.42) * 104)
    shade = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shade.putalpha(vignette.filter(ImageFilter.GaussianBlur(12.0)))
    base.alpha_composite(shade)

    return base.convert("RGB")


def main() -> None:
    if not PLAYER_GUARD.exists() or not ARENA.exists():
        raise SystemExit("required approved v0.7 guard/arena source assets are missing")
    OUT.mkdir(parents=True, exist_ok=True)
    master = build_master()
    for name, size in SLOTS.items():
        img = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
        img.save(OUT / name, format="PNG", optimize=True)
    print(f"generated {len(SLOTS)} opaque icon assets from approved player guard + title-night arena")


if __name__ == "__main__":
    main()
