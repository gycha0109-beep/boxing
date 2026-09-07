#!/usr/bin/env python3
"""Deterministically clean the v0.7 vertical-slice fighter sprites.

This tool intentionally targets only the first commercial vertical slice:
- player: 8 poses
- swarmer: 8 poses

It removes disconnected generative-image contamination while preserving the
largest connected boxer silhouette. It also normalizes the swarmer's blue
shorts contamination in hurt/knockdown poses back to the locked red gear.

Dependencies (tooling only): Pillow, numpy, opencv-python-headless
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets" / "visual" / "v0.7" / "fighters"

PLAYER_FILES = tuple(sorted((ASSET_ROOT / "player").glob("player_base_*.png")))
SWARMER_FILES = tuple(sorted((ASSET_ROOT / "opponents" / "swarmer").glob("op_swarmer_a_*.png")))
TARGET_FILES = PLAYER_FILES + SWARMER_FILES

EXPECTED_SIZE = (512, 512)
ALPHA_CORE_THRESHOLD = 8
DILATION_KERNEL = np.ones((5, 5), dtype=np.uint8)


def _largest_component_mask(alpha: np.ndarray) -> np.ndarray:
    core = (alpha > ALPHA_CORE_THRESHOLD).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(core, connectivity=8)
    if count <= 1:
        raise RuntimeError("sprite contains no opaque connected component")

    component_areas = stats[1:, cv2.CC_STAT_AREA]
    largest_label = 1 + int(np.argmax(component_areas))
    largest = (labels == largest_label).astype(np.uint8)

    # Recover the antialiased fringe around the retained silhouette without
    # allowing distant debris back into the image.
    expanded = cv2.dilate(largest, DILATION_KERNEL, iterations=1).astype(bool)
    return (alpha > 0) & expanded


def _normalize_swarmer_gear(path: Path, rgba: np.ndarray) -> np.ndarray:
    if path.name not in {"op_swarmer_a_hurt.png", "op_swarmer_a_knockdown.png"}:
        return rgba

    rgb = rgba[:, :, :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    alpha = rgba[:, :, 3]

    # The contaminated variants switched the locked red trunks to blue.
    # Restrict the correction to clearly saturated blue/cyan pixels.
    blue = (
        (hsv[:, :, 0] >= 90)
        & (hsv[:, :, 0] <= 135)
        & (hsv[:, :, 1] >= 55)
        & (alpha > 20)
    )
    corrected = hsv.copy()
    corrected[:, :, 0][blue] = 0
    corrected[:, :, 1][blue] = np.clip(
        corrected[:, :, 1][blue].astype(np.int16) + 15, 0, 255
    ).astype(np.uint8)
    corrected_rgb = cv2.cvtColor(corrected, cv2.COLOR_HSV2RGB)
    rgba[:, :, :3] = np.where(blue[:, :, None], corrected_rgb, rgb)
    return rgba


def clean_sprite(path: Path, *, check_only: bool) -> tuple[int, int]:
    image = Image.open(path).convert("RGBA")
    if image.size != EXPECTED_SIZE:
        raise RuntimeError(f"{path}: expected {EXPECTED_SIZE}, got {image.size}")

    rgba = np.array(image)
    original_alpha = rgba[:, :, 3].copy()
    keep = _largest_component_mask(original_alpha)
    removed_pixels = int(np.count_nonzero((original_alpha > 0) & ~keep))

    cleaned = rgba.copy()
    cleaned[~keep, 3] = 0
    cleaned = _normalize_swarmer_gear(path, cleaned)

    remaining_pixels = int(np.count_nonzero(cleaned[:, :, 3] > 0))
    if remaining_pixels <= 0:
        raise RuntimeError(f"{path}: cleanup removed the boxer silhouette")

    if not check_only:
        Image.fromarray(cleaned, mode="RGBA").save(
            path,
            format="PNG",
            optimize=True,
            compress_level=9,
        )

    return removed_pixels, remaining_pixels


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Validate cleanup deterministically without writing PNG files.",
    )
    args = parser.parse_args()

    if len(PLAYER_FILES) != 8 or len(SWARMER_FILES) != 8:
        raise RuntimeError(
            f"expected 8 player + 8 swarmer sprites, got "
            f"{len(PLAYER_FILES)} + {len(SWARMER_FILES)}"
        )

    total_removed = 0
    total_remaining = 0
    for path in TARGET_FILES:
        removed, remaining = clean_sprite(path, check_only=args.check_only)
        total_removed += removed
        total_remaining += remaining
        print(
            f"{'CHECK' if args.check_only else 'CLEAN'} "
            f"{path.relative_to(ROOT)} removed={removed} remaining={remaining}"
        )

    print(
        f"v0.7.1 vertical slice: sprites={len(TARGET_FILES)} "
        f"removed={total_removed} remaining={total_remaining}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
