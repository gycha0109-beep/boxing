#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
PRESET = ROOT / "export_presets.cfg"

ICON_SLOTS = {
    "icons/app_store_1024x1024": ("assets/release/icon/app_store_1024.png", 1024),
    "icons/iphone_180x180": ("assets/release/icon/iphone_180.png", 180),
    "icons/iphone_120x120": ("assets/release/icon/iphone_120.png", 120),
    "icons/notification_60x60": ("assets/release/icon/notification_60.png", 60),
    "icons/notification_40x40": ("assets/release/icon/notification_40.png", 40),
    "icons/settings_87x87": ("assets/release/icon/settings_87.png", 87),
    "icons/settings_58x58": ("assets/release/icon/settings_58.png", 58),
    "icons/spotlight_80x80": ("assets/release/icon/spotlight_80.png", 80),
    "icons/spotlight_40x40": ("assets/release/icon/spotlight_40.png", 40),
}

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def fail(message: str) -> None:
    raise SystemExit(f"app-icon-v1.0: FAIL: {message}")


def preset_value(text: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}=(.*)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def read_png(path: Path) -> tuple[int, int, int, int, bytes, bytes | None]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        fail(f"not a PNG: {path.relative_to(ROOT)}")

    pos = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = -1
    idat = bytearray()
    transparency: bytes | None = None
    saw_ihdr = False

    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8]
        payload_start = pos + 8
        payload_end = payload_start + length
        crc_end = payload_end + 4
        if crc_end > len(data):
            fail(f"truncated PNG chunk in {path.relative_to(ROOT)}")
        payload = data[payload_start:payload_end]

        if chunk_type == b"IHDR":
            if length != 13:
                fail(f"invalid IHDR length in {path.relative_to(ROOT)}")
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if compression != 0 or filtering != 0 or interlace != 0:
                fail(f"unsupported PNG encoding in {path.relative_to(ROOT)}")
            saw_ihdr = True
        elif chunk_type == b"IDAT":
            idat.extend(payload)
        elif chunk_type == b"tRNS":
            transparency = payload
        elif chunk_type == b"IEND":
            break
        pos = crc_end

    if not saw_ihdr:
        fail(f"missing IHDR: {path.relative_to(ROOT)}")
    if bit_depth != 8:
        fail(f"icon must use 8-bit channels: {path.relative_to(ROOT)}")
    if color_type not in {2, 6}:
        fail(f"icon must be RGB or RGBA PNG, got color type {color_type}: {path.relative_to(ROOT)}")
    if not idat:
        fail(f"missing IDAT: {path.relative_to(ROOT)}")
    if transparency is not None:
        fail(f"tRNS transparency is not allowed: {path.relative_to(ROOT)}")
    return width, height, bit_depth, color_type, bytes(idat), transparency


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def assert_opaque_rgba(path: Path, width: int, height: int, compressed: bytes) -> None:
    raw = zlib.decompress(compressed)
    bpp = 4
    stride = width * bpp
    expected = height * (stride + 1)
    if len(raw) != expected:
        fail(f"unexpected RGBA scanline length in {path.relative_to(ROOT)}")

    previous = bytearray(stride)
    cursor = 0
    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        encoded = raw[cursor : cursor + stride]
        cursor += stride
        scanline = bytearray(stride)
        for x, value in enumerate(encoded):
            left = scanline[x - bpp] if x >= bpp else 0
            up = previous[x]
            up_left = previous[x - bpp] if x >= bpp else 0
            if filter_type == 0:
                decoded = value
            elif filter_type == 1:
                decoded = (value + left) & 0xFF
            elif filter_type == 2:
                decoded = (value + up) & 0xFF
            elif filter_type == 3:
                decoded = (value + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                decoded = (value + paeth(left, up, up_left)) & 0xFF
            else:
                fail(f"invalid PNG filter {filter_type} in {path.relative_to(ROOT)}")
            scanline[x] = decoded
        for x in range(3, stride, 4):
            if scanline[x] != 255:
                pixel = x // 4
                fail(
                    f"transparent pixel at ({pixel},{y}) alpha={scanline[x]} "
                    f"in {path.relative_to(ROOT)}"
                )
        previous = scanline


def validate_png(path: Path, expected_size: int) -> None:
    if not path.exists():
        fail(f"missing icon file: {path.relative_to(ROOT)}")
    width, height, _depth, color_type, compressed, _transparency = read_png(path)
    if width != expected_size or height != expected_size:
        fail(
            f"wrong dimensions for {path.relative_to(ROOT)}: "
            f"{width}x{height}, expected {expected_size}x{expected_size}"
        )
    if color_type == 6:
        assert_opaque_rgba(path, width, height, compressed)


def main() -> int:
    if not PRESET.exists():
        fail("export_presets.cfg missing")
    preset = PRESET.read_text(encoding="utf-8")

    for key, (relative_path, expected_size) in ICON_SLOTS.items():
        expected_value = f'"res://{relative_path}"'
        actual = preset_value(preset, key)
        if actual != expected_value:
            fail(f"{key} must be {expected_value}, got {actual!r}")
        validate_png(ROOT / relative_path, expected_size)

    print("app-icon-v1.0: PASS")
    print("app_store_1024=opaque")
    print("device_slots=9")
    print("visual-small-size-review=REQUIRED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
