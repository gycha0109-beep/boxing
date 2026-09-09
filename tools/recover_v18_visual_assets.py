#!/usr/bin/env python3
from __future__ import annotations

import base64
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

CHUNK_RE = re.compile(r'const\s+CHUNK\s*:=\s*"([A-Za-z0-9+/=]+)"')


def read_chunk(name: str) -> str:
    text = (SRC / name).read_text(encoding="utf-8")
    match = CHUNK_RE.search(text)
    if match is None:
        raise SystemExit(f"missing CHUNK in {name}")
    return match.group(1)


def padded(value: str) -> str:
    return value + "=" * ((4 - len(value) % 4) % 4)


def candidates(chunks: list[str]):
    joined = "".join(chunks)
    stripped = "".join(chunk.rstrip("=") for chunk in chunks)
    yield "joined", lambda: base64.b64decode(padded(joined), validate=True)
    yield "joined-strip-inner-padding", lambda: base64.b64decode(padded(stripped), validate=True)
    yield "decode-each-and-append", lambda: b"".join(base64.b64decode(padded(chunk), validate=True) for chunk in chunks)


def verify_jpeg(data: bytes) -> tuple[int, int]:
    if not (data.startswith(b"\xff\xd8") and data.endswith(b"\xff\xd9")):
        raise ValueError("JPEG SOI/EOI markers missing")
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "JPEG":
            raise ValueError(f"unexpected format: {image.format}")
        size = image.size
        image.verify()
    return size


def recover(output_name: str, source_names: list[str]) -> None:
    chunks = [read_chunk(name) for name in source_names]
    print(f"{output_name}: chunk-lengths={[len(c) for c in chunks]}")
    errors: list[str] = []
    for mode, decode in candidates(chunks):
        try:
            data = decode()
            size = verify_jpeg(data)
        except Exception as exc:  # diagnostic path intentionally broad
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
