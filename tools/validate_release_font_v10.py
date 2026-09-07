#!/usr/bin/env python3
from __future__ import annotations

from hashlib import sha1
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "assets/fonts/NotoSansKR-VF.ttf"
LICENSE = ROOT / "assets/fonts/OFL-NotoSansKR.txt"
MAIN_SCENE = ROOT / "scenes/Main.tscn"
RELEASE_SHELL = ROOT / "scripts/main_v10.gd"
IMPORT_WORKFLOW = ROOT / ".github/workflows/import-korean-font-v10.yml"

EXPECTED_FONT_BLOB = "b386890ba945e1f39448a6b59f20c5d194f58808"
EXPECTED_LICENSE_BLOB = "1c9f43281b8f216c5461fe9ac729afbade7724e4"


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    return sha1(f"blob {len(data)}\0".encode() + data).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"release-font-v1.0: FAIL: {message}")


def main() -> None:
    require(FONT.is_file(), "bundled Noto Sans KR font is missing")
    require(LICENSE.is_file(), "Noto Sans KR OFL license is missing")
    require(FONT.stat().st_size >= 1_000_000, f"font is unexpectedly small: {FONT.stat().st_size} bytes")
    require(git_blob_sha(FONT) == EXPECTED_FONT_BLOB, "font does not match pinned upstream Google Fonts blob")
    require(git_blob_sha(LICENSE) == EXPECTED_LICENSE_BLOB, "license does not match pinned upstream Google Fonts blob")

    license_text = LICENSE.read_text(encoding="utf-8")
    require("SIL OPEN FONT LICENSE Version 1.1" in license_text, "OFL 1.1 marker is missing")

    scene_text = MAIN_SCENE.read_text(encoding="utf-8")
    shell_text = RELEASE_SHELL.read_text(encoding="utf-8")
    require('res://scripts/main_v10.gd' in scene_text, "Main scene is not routed through the v1.0 release shell")
    require('extends "res://scripts/main_v08.gd"' in shell_text, "v1.0 release shell no longer preserves v0.8 flow")
    require('res://assets/fonts/NotoSansKR-VF.ttf' in shell_text, "release shell does not reference the bundled font")
    require("as FontFile" in shell_text, "release shell does not require a FontFile resource")
    require("allow_system_fallback = false" in shell_text, "release font can still fall back to OS fonts")
    require("SystemFont.new" not in shell_text, "release shell constructs a system font")
    require(not IMPORT_WORKFLOW.exists(), "one-shot font importer must be removed before release QA")

    print("release-font-v1.0: PASS")
    print(f"font-bytes={FONT.stat().st_size}")
    print(f"font-git-blob={EXPECTED_FONT_BLOB}")
    print(f"license-git-blob={EXPECTED_LICENSE_BLOB}")


if __name__ == "__main__":
    main()
