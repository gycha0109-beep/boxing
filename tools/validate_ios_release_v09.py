#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PRESET = ROOT / "export_presets.cfg"
PROJECT = ROOT / "project.godot"

REQUIRED_DOCS = [
    ROOT / "docs" / "release" / "ios-release-v0.9.md",
    ROOT / "docs" / "release" / "app-store-metadata-ko.md",
    ROOT / "docs" / "release" / "privacy-policy-ko.md",
]


def fail(message: str) -> None:
    raise SystemExit(f"ios-release-v0.9: FAIL: {message}")


def require_text(haystack: str, needle: str, label: str) -> None:
    if needle not in haystack:
        fail(f"missing {label}: {needle}")


def option_value(text: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}=(.*)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def main() -> int:
    if not PRESET.exists():
        fail("export_presets.cfg missing")
    if not PROJECT.exists():
        fail("project.godot missing")

    preset = PRESET.read_text(encoding="utf-8")
    project = PROJECT.read_text(encoding="utf-8")

    require_text(preset, 'name="iOS Release"', "release preset name")
    require_text(preset, 'platform="iOS"', "iOS platform")
    require_text(preset, "architectures/arm64=true", "arm64 architecture")
    require_text(preset, "application/targeted_device_family=0", "iPhone-only target")
    require_text(preset, 'application/min_ios_version="15.0"', "minimum iOS version")
    require_text(preset, "application/export_project_only=true", "Xcode-project export mode")
    require_text(preset, "capabilities/access_wifi=false", "offline Wi-Fi capability boundary")
    require_text(preset, 'entitlements/push_notifications="Disabled"', "push-notification boundary")
    require_text(preset, "entitlements/game_center=false", "Game Center boundary")
    require_text(preset, "user_data/accessible_from_files_app=false", "Files app boundary")
    require_text(preset, "user_data/accessible_from_itunes_sharing=false", "iTunes sharing boundary")
    require_text(preset, 'privacy/camera_usage_description=""', "camera privacy boundary")
    require_text(preset, 'privacy/microphone_usage_description=""', "microphone privacy boundary")
    require_text(preset, 'privacy/photolibrary_usage_description=""', "photo-library privacy boundary")

    require_text(project, 'config/name="Twelve Count"', "product name")
    require_text(project, "window/size/viewport_width=430", "portrait viewport width")
    require_text(project, "window/size/viewport_height=932", "portrait viewport height")
    require_text(project, "window/handheld/orientation=1", "portrait orientation")

    for path in REQUIRED_DOCS:
        if not path.exists():
            fail(f"required release document missing: {path.relative_to(ROOT)}")

    team_id = option_value(preset, "application/app_store_team_id")
    bundle_id = option_value(preset, "application/bundle_identifier")
    app_icon = option_value(preset, "icons/app_store_1024x1024")

    signing_ready = team_id not in {None, '""'} and bundle_id not in {None, '""'}
    icon_ready = app_icon not in {None, '""'}

    if "--require-signing" in sys.argv:
        if not signing_ready:
            fail("Apple Team ID and Bundle ID are still blank")
        if not icon_ready:
            fail("App Store 1024x1024 icon is still blank")

    print("ios-release-v0.9: PASS")
    print(f"signing_ready={str(signing_ready).lower()}")
    print(f"app_icon_ready={str(icon_ready).lower()}")
    if not signing_ready:
        print("release-signing-gate: HOLD (Team ID / Bundle ID required before real iOS export)")
    if not icon_ready:
        print("release-icon-gate: HOLD (final opaque 1024x1024 app icon required before submission)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
