#!/usr/bin/env python3
from __future__ import annotations

import argparse
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets" / "visual" / "v0.7"
POSES = ["idle", "jab", "power", "body", "guard", "counter", "hurt", "knockdown"]
STYLES = ["swarmer", "outboxer", "slugger", "counter"]


def expected() -> list[tuple[Path, tuple[int, int]]]:
    files: list[tuple[Path, tuple[int, int]]] = []
    for pose in POSES:
        files.append((ASSET_ROOT / "fighters" / "player" / f"player_base_{pose}.png", (256, 256)))
    for style in STYLES:
        for pose in POSES:
            files.append((ASSET_ROOT / "fighters" / "opponents" / style / f"op_{style}_a_{pose}.png", (256, 256)))
        files.append((ASSET_ROOT / "portraits" / f"portrait_{style}_a.png", (256, 256)))
    files.append((ASSET_ROOT / "portraits" / "portrait_player_a.png", (256, 256)))
    files.append((ASSET_ROOT / "arena" / "arena_gym_basic.png", (720, 1000)))
    files.append((ASSET_ROOT / "arena" / "arena_title_night.png", (720, 1000)))
    for name in [
        "fx_hit_jab_01.png", "fx_hit_power_01.png", "fx_hit_body_01.png",
        "fx_block_01.png", "fx_counter_flash_01.png", "fx_knockdown_burst_01.png",
    ]:
        files.append((ASSET_ROOT / "fx" / name, (128, 128)))
    return files


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        header = f.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("not a valid PNG IHDR")
    return struct.unpack(">II", header[16:24])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="fail when the asset pack is not installed")
    args = parser.parse_args()

    if not ASSET_ROOT.exists():
        message = f"v0.7 visual assets not installed: {ASSET_ROOT.relative_to(ROOT)}"
        if args.strict:
            raise SystemExit(message)
        print(f"visual_assets_v07: PENDING ({message})")
        return 0

    failures: list[str] = []
    required = expected()
    for path, minimum in required:
        rel = path.relative_to(ROOT)
        if not path.exists():
            failures.append(f"missing: {rel}")
            continue
        try:
            width, height = png_dimensions(path)
        except Exception as exc:
            failures.append(f"invalid PNG {rel}: {exc}")
            continue
        if width < minimum[0] or height < minimum[1]:
            failures.append(f"undersized {rel}: {width}x{height}, expected >= {minimum[0]}x{minimum[1]}")

    if failures:
        raise SystemExit("visual_assets_v07 FAIL\n" + "\n".join(failures))

    print(f"visual_assets_v07: PASS ({len(required)} required commercial assets)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
