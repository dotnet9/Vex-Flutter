"""Encode the design-prototype captures into the GIFs used by vex.codewf.com.

Frames come from `scripts/design-capture.mjs` (one folder + `<name>-frames.json`
manifest per scene). Only Pillow is required — the same dependency the README
media pipeline uses.

    python scripts/docs/encode_gifs.py artifacts/design-capture

Writes `docs/media/<name>.gif`, which the website sync copies to
`/assets/vex/media/` and the landing page picks up by file name.
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops

# Recording folder -> output GIF. Explicit so a renamed recording cannot ship
# under the wrong name.
RECORDINGS = {
    "views-instant": "views-instant.gif",
    "views-source": "views-source.gif",
    "views-read": "views-read.gif",
    "views-mindmap": "views-mindmap.gif",
    "mindmap-structures": "mindmap-structures.gif",
    "markdown-formulas": "markdown-formulas.gif",
    "markdown-mermaid": "markdown-mermaid.gif",
    "appearance-themes": "appearance-themes.gif",
    "export-formats": "export-formats.gif",
}

# The page shows these at roughly 1100 px wide; 1200 keeps text crisp without
# shipping 1280 px of pixels nobody sees.
TARGET_WIDTH = 1200
MAX_BYTES = 2_500_000


def load(source: Path, name: str) -> tuple[list[Image.Image], list[int]]:
    manifest = json.loads((source / f"{name}-frames.json").read_text(encoding="utf-8"))
    if not manifest:
        raise ValueError(f"{name}: no frames recorded.")
    frames: list[Image.Image] = []
    durations: list[int] = []
    for row in manifest:
        path = (source / row["file"]).resolve()
        if not path.is_relative_to(source.resolve()):
            raise ValueError(f"{name}: a frame path escapes the capture directory.")
        duration = row["durationMs"]
        if not isinstance(duration, int) or duration < 10 or duration % 10:
            raise ValueError(f"{name}: frame durations must be positive 10 ms multiples.")
        with Image.open(path) as image:
            frame = image.convert("RGB")
        if frame.width != TARGET_WIDTH:
            frame = frame.resize(
                (TARGET_WIDTH, round(frame.height * TARGET_WIDTH / frame.width)),
                Image.LANCZOS,
            )
        if frames and frame.size != frames[0].size:
            raise ValueError(f"{name}: all frames must share one size.")
        frames.append(frame)
        durations.append(duration)
    return frames, durations


def palette_for(frames: list[Image.Image]) -> Image.Image:
    """One palette for the whole clip keeps UI text and quiet surfaces stable."""
    tile_w, tile_h = 200, 125
    sheet = Image.new("RGB", (tile_w * len(frames), tile_h))
    for index, frame in enumerate(frames):
        sheet.paste(frame.resize((tile_w, tile_h)), (index * tile_w, 0))
    return sheet.quantize(colors=256)


def encode(frames: list[Image.Image], durations: list[int], destination: Path) -> None:
    palette = palette_for(frames)
    indexed = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    indexed[0].save(
        destination,
        save_all=True,
        append_images=indexed[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=1,
    )
    with Image.open(destination) as recorded:
        elapsed = 0
        for index in range(recorded.n_frames):
            recorded.seek(index)
            elapsed += recorded.info["duration"]
        if recorded.size != frames[0].size:
            raise ValueError(f"{destination.name}: encoded size does not match.")
        if elapsed != sum(durations):
            raise ValueError(f"{destination.name}: encoded duration does not match.")
        expected = indexed[-1].convert("RGB")
        if ImageChops.difference(recorded.convert("RGB"), expected).getbbox():
            raise ValueError(f"{destination.name}: final frame differs from the capture.")
        size = destination.stat().st_size
        print(
            f"{destination.name}: {recorded.n_frames} frames, {elapsed / 1000:.2f}s, "
            f"{recorded.size[0]}x{recorded.size[1]}, {size:,} bytes"
            + ("  [over budget]" if size > MAX_BYTES else "")
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="output directory of design-capture.mjs")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "docs/media",
    )
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    missing: list[str] = []
    for name, gif in RECORDINGS.items():
        if not (args.source / f"{name}-frames.json").exists():
            missing.append(name)
            continue
        frames, durations = load(args.source, name)
        encode(frames, durations, args.output / gif)
    if missing:
        print("not recorded (skipped): " + ", ".join(missing))


if __name__ == "__main__":
    main()
