#!/usr/bin/env python3
"""Deterministically clean the v0.7 commercial fighter sprite pack.

The generated source pack contains disconnected body fragments, scan-line
residue, gear-color drift, and two pose-level quality failures. This tool keeps
the dominant boxer silhouette for all 40 fighter sprites, applies narrowly
scoped gear corrections, and uses deterministic same-pack substitutes for two
unusable frames:

- out-boxer idle reuses the cleaned out-boxer guard frame (gear consistency)
- counter knockdown reuses the cleaned out-boxer knockdown silhouette with a
  purple gear conversion (the original counter knockdown is only a body shard)

The substitutions intentionally prefer a duplicated readable pose over a
visibly corrupted generative frame for the commercial v1 release.

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
OPPONENT_ROOT = ASSET_ROOT / "opponents"

PLAYER_FILES = tuple(sorted((ASSET_ROOT / "player").glob("player_base_*.png")))
OPPONENT_STYLES = ("swarmer", "outboxer", "slugger", "counter")
OPPONENT_FILES = {
    style: tuple(sorted((OPPONENT_ROOT / style).glob(f"op_{style}_a_*.png")))
    for style in OPPONENT_STYLES
}
TARGET_FILES = PLAYER_FILES + tuple(
    path for style in OPPONENT_STYLES for path in OPPONENT_FILES[style]
)

EXPECTED_SIZE = (512, 512)
EXPECTED_POSES_PER_FIGHTER = 8
EXPECTED_TOTAL = 40
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

    # These two generated variants switched the locked red trunks to blue.
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


def _counter_palette_from_outboxer(rgba: np.ndarray) -> np.ndarray:
    """Convert saturated out-boxer blue gear toward counter purple gear."""
    rgb = rgba[:, :, :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    alpha = rgba[:, :, 3]
    blue = (
        (hsv[:, :, 0] >= 90)
        & (hsv[:, :, 0] <= 135)
        & (hsv[:, :, 1] >= 40)
        & (alpha > 20)
    )
    corrected = hsv.copy()
    corrected[:, :, 0][blue] = 145
    corrected_rgb = cv2.cvtColor(corrected, cv2.COLOR_HSV2RGB)
    result = rgba.copy()
    result[:, :, :3] = np.where(blue[:, :, None], corrected_rgb, rgb)
    return result


def _load_rgba(path: Path) -> np.ndarray:
    image = Image.open(path).convert("RGBA")
    if image.size != EXPECTED_SIZE:
        raise RuntimeError(f"{path}: expected {EXPECTED_SIZE}, got {image.size}")
    return np.array(image)


def _save_rgba(path: Path, rgba: np.ndarray) -> None:
    Image.fromarray(rgba, mode="RGBA").save(
        path,
        format="PNG",
        optimize=True,
        compress_level=9,
    )


def clean_sprite(path: Path, *, check_only: bool) -> tuple[int, int]:
    rgba = _load_rgba(path)
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
        _save_rgba(path, cleaned)

    return removed_pixels, remaining_pixels


def _apply_quality_substitutions(*, check_only: bool) -> None:
    outboxer_guard = OPPONENT_ROOT / "outboxer" / "op_outboxer_a_guard.png"
    outboxer_idle = OPPONENT_ROOT / "outboxer" / "op_outboxer_a_idle.png"
    outboxer_down = OPPONENT_ROOT / "outboxer" / "op_outboxer_a_knockdown.png"
    counter_down = OPPONENT_ROOT / "counter" / "op_counter_a_knockdown.png"

    guard_rgba = _load_rgba(outboxer_guard)
    idle_rgba = _load_rgba(outboxer_idle)
    expected_counter_down = _counter_palette_from_outboxer(_load_rgba(outboxer_down))
    current_counter_down = _load_rgba(counter_down)

    if check_only:
        if not np.array_equal(idle_rgba, guard_rgba):
            raise RuntimeError("out-boxer idle substitution is not canonical")
        if not np.array_equal(current_counter_down, expected_counter_down):
            raise RuntimeError("counter knockdown substitution is not canonical")
        return

    _save_rgba(outboxer_idle, guard_rgba)
    _save_rgba(counter_down, expected_counter_down)
    print("QUALITY FIX out-boxer idle <- cleaned guard")
    print("QUALITY FIX counter knockdown <- cleaned out-boxer knockdown + purple gear")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Validate cleanup deterministically without writing PNG files.",
    )
    args = parser.parse_args()

    if len(PLAYER_FILES) != EXPECTED_POSES_PER_FIGHTER:
        raise RuntimeError(
            f"expected {EXPECTED_POSES_PER_FIGHTER} player sprites, got {len(PLAYER_FILES)}"
        )
    for style in OPPONENT_STYLES:
        if len(OPPONENT_FILES[style]) != EXPECTED_POSES_PER_FIGHTER:
            raise RuntimeError(
                f"expected {EXPECTED_POSES_PER_FIGHTER} {style} sprites, "
                f"got {len(OPPONENT_FILES[style])}"
            )
    if len(TARGET_FILES) != EXPECTED_TOTAL:
        raise RuntimeError(f"expected {EXPECTED_TOTAL} fighter sprites, got {len(TARGET_FILES)}")

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

    _apply_quality_substitutions(check_only=args.check_only)

    print(
        f"v0.7.1 commercial fighter pack: sprites={len(TARGET_FILES)} "
        f"removed={total_removed} remaining={total_remaining}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
