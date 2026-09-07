#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
PORTRAIT = ROOT / "assets/visual/v0.7/portraits/portrait_player_a.png"
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


def build_master() -> Image.Image:
    arena = Image.open(ARENA).convert("RGB")
    arena = cover(arena, 1024).filter(ImageFilter.GaussianBlur(3.0))
    arena = ImageEnhance.Brightness(arena).enhance(0.48)
    arena = ImageEnhance.Color(arena).enhance(0.72)

    # Cool navy release grade.
    navy = Image.new("RGB", (1024, 1024), (7, 15, 25))
    base = Image.blend(arena, navy, 0.30)

    portrait = Image.open(PORTRAIT).convert("RGBA")
    portrait = cover(portrait, 1024)

    # Preserve the accepted player portrait, but increase large-shape contrast for small icon sizes.
    rgb = ImageEnhance.Contrast(portrait.convert("RGB")).enhance(1.10)
    rgb = ImageEnhance.Color(rgb).enhance(1.06)
    portrait = rgb.convert("RGBA")

    # If the source carries transparency, use it. Otherwise a soft radial feather prevents a hard square seam.
    alpha = Image.open(PORTRAIT).convert("RGBA")
    alpha = cover(alpha, 1024).getchannel("A")
    if alpha.getextrema() == (255, 255):
        mask = Image.new("L", (1024, 1024), 0)
        px = mask.load()
        cx, cy = 520.0, 500.0
        rx, ry = 520.0, 560.0
        for y in range(1024):
            dy = (y - cy) / ry
            for x in range(1024):
                dx = (x - cx) / rx
                d = (dx * dx + dy * dy) ** 0.5
                a = int(max(0.0, min(1.0, (1.08 - d) / 0.14)) * 255)
                px[x, y] = a
        alpha = mask.filter(ImageFilter.GaussianBlur(8.0))
    portrait.putalpha(alpha)

    # Gold halo supports the product's dossier/fight-night palette without adding text or chrome.
    halo = alpha.filter(ImageFilter.GaussianBlur(20.0))
    gold = Image.new("RGBA", (1024, 1024), (196, 151, 73, 0))
    gold.putalpha(halo.point(lambda p: int(p * 0.24)))
    base_rgba = base.convert("RGBA")
    base_rgba.alpha_composite(gold)
    base_rgba.alpha_composite(portrait)

    # Subtle vignette, never rounded: all four corners remain real artwork and fully opaque.
    vig = Image.new("L", (1024, 1024), 0)
    vp = vig.load()
    for y in range(1024):
        ny = abs(y - 511.5) / 511.5
        for x in range(1024):
            nx = abs(x - 511.5) / 511.5
            edge = max(nx, ny)
            vp[x, y] = int(max(0.0, (edge - 0.55) / 0.45) * 115)
    shade = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shade.putalpha(vig.filter(ImageFilter.GaussianBlur(12.0)))
    base_rgba.alpha_composite(shade)

    return base_rgba.convert("RGB")


def main() -> None:
    if not PORTRAIT.exists() or not ARENA.exists():
        raise SystemExit("required v0.7 source assets are missing")
    OUT.mkdir(parents=True, exist_ok=True)
    master = build_master()
    for name, size in SLOTS.items():
        img = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
        img.save(OUT / name, format="PNG", optimize=True)
    print(f"generated {len(SLOTS)} opaque icon assets from approved v0.7 sources")


if __name__ == "__main__":
    main()
