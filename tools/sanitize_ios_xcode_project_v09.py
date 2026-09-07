#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import plistlib
import re
import sys

UNUSED_PRIVACY_KEYS = (
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
)

EMPTY_STRINGS_LINE = re.compile(
    r'^\s*(NSCameraUsageDescription|NSMicrophoneUsageDescription|NSPhotoLibraryUsageDescription)\s*=\s*"";\s*$'
)


def sanitize_plist(path: Path) -> list[str]:
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    removed: list[str] = []
    for key in UNUSED_PRIVACY_KEYS:
        value = data.get(key)
        if value == "":
            del data[key]
            removed.append(key)
    if removed:
        with path.open("wb") as handle:
            plistlib.dump(data, handle, fmt=plistlib.FMT_XML, sort_keys=False)
    return removed


def sanitize_strings(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    removed: list[str] = []
    kept: list[str] = []
    for line in text.splitlines():
        match = EMPTY_STRINGS_LINE.match(line)
        if match:
            removed.append(match.group(1))
            continue
        kept.append(line)
    if removed:
        path.write_text("\n".join(kept) + "\n", encoding="utf-8")
    return removed


def verify_no_blank_usage_values(root: Path) -> None:
    failures: list[str] = []
    for plist in root.rglob("*-Info.plist"):
        with plist.open("rb") as handle:
            data = plistlib.load(handle)
        for key in UNUSED_PRIVACY_KEYS:
            if data.get(key) == "":
                failures.append(f"{plist}: {key} is blank")
    for strings in root.rglob("InfoPlist.strings"):
        for line in strings.read_text(encoding="utf-8").splitlines():
            match = EMPTY_STRINGS_LINE.match(line)
            if match:
                failures.append(f"{strings}: {match.group(1)} is blank")
    if failures:
        raise SystemExit("ios-xcode-sanitize: FAIL\n" + "\n".join(failures))


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: sanitize_ios_xcode_project_v09.py <generated-ios-root>")
    root = Path(sys.argv[1]).resolve()
    if not root.is_dir():
        raise SystemExit(f"ios-xcode-sanitize: FAIL: not a directory: {root}")

    plist_files = list(root.rglob("*-Info.plist"))
    if not plist_files:
        raise SystemExit(f"ios-xcode-sanitize: FAIL: no generated *-Info.plist under {root}")

    changes: list[str] = []
    for plist in plist_files:
        removed = sanitize_plist(plist)
        if removed:
            changes.append(f"{plist.relative_to(root)}: removed {','.join(removed)}")

    for strings in root.rglob("InfoPlist.strings"):
        removed = sanitize_strings(strings)
        if removed:
            changes.append(f"{strings.relative_to(root)}: removed {','.join(removed)}")

    verify_no_blank_usage_values(root)
    print("ios-xcode-sanitize: PASS")
    for change in changes:
        print(change)
    if not changes:
        print("no blank unused privacy usage descriptions found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
