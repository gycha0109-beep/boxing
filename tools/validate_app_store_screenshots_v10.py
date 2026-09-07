#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
SCREENSHOT_DIR = ROOT / "assets" / "release" / "screenshots" / "ko-KR" / "iphone-6.9"
TARGET = (1260, 2736)
FILES = [
    "01_fight_impact.png",
    "02_fight_opening.png",
    "03_camp.png",
    "04_scouting_game_plan.png",
    "05_fight_offer.png",
    "06_weigh_in.png",
    "07_result.png",
    "08_title.png",
]


def fail(message: str) -> None:
    raise SystemExit(f"app-store-screenshots-v1.0: FAIL: {message}")


def inspect_png(path: Path) -> tuple[int, int, int, bool]:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"not a PNG: {path.relative_to(ROOT)}")
    if data[12:16] != b"IHDR":
        fail(f"missing IHDR: {path.relative_to(ROOT)}")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    has_trns = b"tRNS" in data
    return width, height, color_type, has_trns


def main() -> int:
    if not SCREENSHOT_DIR.exists():
        fail(f"screenshot directory missing: {SCREENSHOT_DIR.relative_to(ROOT)}")

    actual_names = sorted(p.name for p in SCREENSHOT_DIR.glob("*.png"))
    if actual_names != sorted(FILES):
        fail(f"unexpected screenshot set: {actual_names}")

    for name in FILES:
        path = SCREENSHOT_DIR / name
        width, height, color_type, has_trns = inspect_png(path)
        if (width, height) != TARGET:
            fail(f"{name} is {width}x{height}; expected {TARGET[0]}x{TARGET[1]}")
        if color_type in {4, 6} or has_trns:
            fail(f"{name} contains alpha/transparency")
        if color_type not in {0, 2}:
            fail(f"{name} uses unsupported PNG color type {color_type}")

    print("app-store-screenshots-v1.0: PASS")
    print("locale=ko-KR")
    print("device=iPhone 6.9-inch")
    print("size=1260x2736")
    print("order=fight-impact,fight-opening,camp,scouting,fight-offer,weigh-in,result,title")
    print(f"count={len(FILES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
