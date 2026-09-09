#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import io
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "scripts" / "ui" / "v18_assets"
OUT = ROOT / "assets" / "visual" / "v18"

SETS = {
    "hero_player.jpg": ["hero_player_00.gd", "hero_player_01.gd"],
    "training_atlas.jpg": ["training_atlas_00.gd", "training_atlas_01.gd"],
    "opponent_atlas.jpg": ["opponent_atlas_00.gd", "opponent_atlas_01.gd"],
    "fight_ring_scene.jpg": ["fight_ring_scene_00.gd", "fight_ring_scene_01.gd", "fight_ring_scene_02.gd"],
}

REPAIR_SUFFIX = {
    "hero_player_00.gd": "3iMSmgaVxsr7",
    "training_atlas_00.gd": "5ZftAmjLHa+h",
    "opponent_atlas_00.gd": "uXgHjvoWY4CX",
    "fight_ring_scene_00.gd": "bzXcQmkEEw7Y",
    "fight_ring_scene_01.gd": "oB1gjC1rOIuz",
}

EXPECTED_CHUNK_SHA256 = {
    "hero_player_00.gd": "b86537b363a4551edbae9a2ec11e2688feee53d5a824aa7ac10eafb21b0d397b",
    "hero_player_01.gd": "2f3611004df02a96a0a87310ecc828f0093fc936ecd2aed5d16658bcb1c90c1b",
    "training_atlas_00.gd": "cddd61fbc242b7385f3a5eec64814e9e7fdd833fc22a7aae5e19dadebbecd927",
    "training_atlas_01.gd": "b8ac8364ed664628b903198a7559e3dc4401fa6ab1c2f9ad763cd4cedddbb4b3",
    "opponent_atlas_00.gd": "9394633354826501a388934226ffd30310ba952657687fca9e3ca9cb817b6894",
    "opponent_atlas_01.gd": "46df3d106030842e235dbff3072ec4deb9165dd0eb51cedeeaa8c0d7203743a4",
    "fight_ring_scene_00.gd": "156c11c521f3e326dbc0eedda2cf8c4c7bc10f8cf05566b96c373c69f63b4e65",
    "fight_ring_scene_01.gd": "502550cc951d8803d827de9d044bdc817fa08acddd20f739c3631d88a453cbf8",
    "fight_ring_scene_02.gd": "28a8fb21c7385ff12d19a42962fe2a723d453a3e8489ece115e1af9d4a37b37d",
}

EXPECTED_SIZES = {
    "hero_player.jpg": (210, 338),
    "training_atlas.jpg": (520, 188),
    "opponent_atlas.jpg": (160, 605),
    "fight_ring_scene.jpg": (460, 333),
}

CHUNK_RE = re.compile(r'const\s+CHUNK\s*:=\s*"([A-Za-z0-9+/=]+)"')


def read_chunk(name: str) -> str:
    text = (SRC / name).read_text(encoding="utf-8")
    match = CHUNK_RE.search(text)
    if match is None:
        raise SystemExit(f"missing CHUNK in {name}")
    value = match.group(1)
    suffix = REPAIR_SUFFIX.get(name)
    if suffix is not None:
        if len(value) == 14_988:
            print(f"{name}: repairing clipped 12-char suffix")
            value += suffix
        elif len(value) != 15_000:
            raise SystemExit(f"{name}: unexpected chunk length {len(value)}")
    actual = hashlib.sha256(value.encode("ascii")).hexdigest()
    expected = EXPECTED_CHUNK_SHA256[name]
    print(f"{name}: len={len(value)} sha256={actual} expected={expected}")
    if actual != expected:
        raise SystemExit(f"{name}: source chunk differs from locally verified v18 source")
    return value


def padded(value: str) -> str:
    return value + "=" * ((4 - len(value) % 4) % 4)


def candidates(chunks: list[str]):
    joined = "".join(chunks)
    stripped = "".join(chunk.rstrip("=") for chunk in chunks)
    yield "joined", lambda: base64.b64decode(padded(joined), validate=True)
    yield "joined-strip-inner-padding", lambda: base64.b64decode(padded(stripped), validate=True)
    yield "decode-each-and-append", lambda: b"".join(base64.b64decode(padded(chunk), validate=True) for chunk in chunks)


def verify_jpeg(data: bytes, expected_size: tuple[int, int]) -> tuple[int, int]:
    if not (data.startswith(b"\xff\xd8") and data.endswith(b"\xff\xd9")):
        raise ValueError("JPEG SOI/EOI markers missing")
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "JPEG":
            raise ValueError(f"unexpected format: {image.format}")
        size = image.size
        if size != expected_size:
            raise ValueError(f"unexpected size: {size}, expected {expected_size}")
        image.verify()
    return size


def recover(output_name: str, source_names: list[str]) -> None:
    chunks = [read_chunk(name) for name in source_names]
    print(f"{output_name}: chunk-lengths={[len(c) for c in chunks]}")
    errors: list[str] = []
    for mode, decode in candidates(chunks):
        try:
            data = decode()
            size = verify_jpeg(data, EXPECTED_SIZES[output_name])
        except Exception as exc:
            errors.append(f"{mode}: {type(exc).__name__}: {exc}")
            continue
        OUT.mkdir(parents=True, exist_ok=True)
        target = OUT / output_name
        target.write_bytes(data)
        print(f"{output_name}: RECOVERED mode={mode} bytes={len(data)} size={size[0]}x{size[1]}")
        return
    raise SystemExit(f"{output_name}: no valid reconstruction\n  " + "\n  ".join(errors))


def main() -> None:
    for output_name, source_names in SETS.items():
        recover(output_name, source_names)
    print("recover-v18-visual-assets: PASS")


if __name__ == "__main__":
    main()
