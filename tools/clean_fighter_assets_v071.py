#!/usr/bin/env python3
"""Deterministically clean the v0.7 commercial fighter sprite pack.

The generated source pack contains disconnected body fragments, scan-line
residue, gear-color drift, and style-level crop failures. This tool keeps the
dominant boxer silhouette for all 40 fighter sprites, applies narrowly scoped
gear corrections, and replaces unreadable/cropped source poses with
deterministic same-pack full-body substitutes.

Commercial v0.7.1 substitution policy:
- out-boxer idle reuses cleaned out-boxer guard for gear/identity consistency.
- slugger standing/down poses derive from the cleaned player pose set, widened
  slightly to preserve a heavier silhouette while retaining full legs/feet.
- counter poses derive from the cleaned out-boxer pose set, converted from blue
  gear to purple and narrowed slightly for a lean counter-puncher silhouette.

The substitutions intentionally prefer readable, reproducible silhouettes over
visibly corrupted generative frames for the commercial v1 release.

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

POSES = ("idle", "guard", "jab", "power", "body", "counter", "hurt", "knockdown")
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
    result = rgba.copy()
    result[:, :, :3] = np.where(blue[:, :, None], corrected_rgb, rgb)
    return result


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
    corrected[:, :, 1][blue] = np.clip(
        corrected[:, :, 1][blue].astype(np.int16) + 12, 0, 255
    ).astype(np.uint8)
    corrected_rgb = cv2.cvtColor(corrected, cv2.COLOR_HSV2RGB)
    result = rgba.copy()
    result[:, :, :3] = np.where(blue[:, :, None], corrected_rgb, rgb)
    return result


def _alpha_bbox(rgba: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(rgba[:, :, 3] > ALPHA_CORE_THRESHOLD)
    if len(xs) == 0:
        raise RuntimeError("sprite contains no visible alpha bounds")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _canonicalize_component(rgba: np.ndarray) -> np.ndarray:
    keep = _largest_component_mask(rgba[:, :, 3])
    result = rgba.copy()
    result[~keep, 3] = 0
    return result


def _scale_content(rgba: np.ndarray, width_scale: float) -> np.ndarray:
    """Scale visible content horizontally and immediately canonicalize alpha."""
    if abs(width_scale - 1.0) < 0.0001:
        return _canonicalize_component(rgba.copy())

    x0, y0, x1, y1 = _alpha_bbox(rgba)
    crop = rgba[y0:y1, x0:x1]
    source_h, source_w = crop.shape[:2]
    target_w = max(1, int(round(source_w * width_scale)))

    resized = cv2.resize(crop, (target_w, source_h), interpolation=cv2.INTER_LANCZOS4)
    center_x = (x0 + x1) / 2.0
    dest_x0 = int(round(center_x - target_w / 2.0))
    dest_x1 = dest_x0 + target_w

    src_x0 = 0
    src_x1 = target_w
    if dest_x0 < 0:
        src_x0 = -dest_x0
        dest_x0 = 0
    if dest_x1 > EXPECTED_SIZE[0]:
        src_x1 -= dest_x1 - EXPECTED_SIZE[0]
        dest_x1 = EXPECTED_SIZE[0]

    result = np.zeros_like(rgba)
    result[y0:y1, dest_x0:dest_x1] = resized[:, src_x0:src_x1]
    return _canonicalize_component(result)


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


def _player_pose_path(pose: str) -> Path:
    return ASSET_ROOT / "player" / f"player_base_{pose}.png"


def _opponent_pose_path(style: str, pose: str) -> Path:
    return OPPONENT_ROOT / style / f"op_{style}_a_{pose}.png"


def _expected_slugger_pose(pose: str) -> np.ndarray:
    donor = _load_rgba(_player_pose_path(pose))
    return _scale_content(donor, 1.14)


def _expected_counter_pose(pose: str) -> np.ndarray:
    donor = _load_rgba(_opponent_pose_path("outboxer", pose))
    donor = _counter_palette_from_outboxer(donor)
    return _scale_content(donor, 0.96)


def _assert_readable_full_body(label: str, rgba: np.ndarray, pose: str) -> None:
    x0, y0, x1, y1 = _alpha_bbox(rgba)
    width = x1 - x0
    height = y1 - y0
    if width < 55 or height < 90:
        raise RuntimeError(f"{label} {pose}: unreadable alpha bounds {width}x{height}")
    if pose != "knockdown" and height < 180:
        raise RuntimeError(f"{label} {pose}: standing silhouette too short ({height}px)")


def _apply_quality_substitutions(*, check_only: bool) -> None:
    outboxer_guard = _opponent_pose_path("outboxer", "guard")
    outboxer_idle = _opponent_pose_path("outboxer", "idle")
    guard_rgba = _load_rgba(outboxer_guard)

    if check_only:
        if not np.array_equal(_load_rgba(outboxer_idle), guard_rgba):
            raise RuntimeError("out-boxer idle substitution is not canonical")
    else:
        _save_rgba(outboxer_idle, guard_rgba)
        print("QUALITY FIX out-boxer idle <- cleaned guard")

    for pose in POSES:
        slugger_path = _opponent_pose_path("slugger", pose)
        counter_path = _opponent_pose_path("counter", pose)
        expected_slugger = _expected_slugger_pose(pose)
        expected_counter = _expected_counter_pose(pose)
        _assert_readable_full_body("slugger", expected_slugger, pose)
        _assert_readable_full_body("counter", expected_counter, pose)

        if check_only:
            if not np.array_equal(_load_rgba(slugger_path), expected_slugger):
                raise RuntimeError(f"slugger {pose} substitution is not canonical")
            if not np.array_equal(_load_rgba(counter_path), expected_counter):
                raise RuntimeError(f"counter {pose} substitution is not canonical")
        else:
            _save_rgba(slugger_path, expected_slugger)
            _save_rgba(counter_path, expected_counter)
            print(f"QUALITY FIX slugger {pose} <- player {pose} + heavy silhouette")
            print(f"QUALITY FIX counter {pose} <- out-boxer {pose} + counter palette")


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
