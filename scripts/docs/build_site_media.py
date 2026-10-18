"""Encode native site captures (vex.codewf.com landing page) into GIFs.

Companion to `build_media.py` (which encodes the README media). Each recording
produced by `apps/vex/integration_test/site_media_capture_test.dart` lives in its
own folder with a `<name>-frames.json` manifest of `{file, durationMs}` rows.

    python scripts/docs/build_site_media.py artifacts/site-capture

Outputs into `docs/media/` the files the website sync copies to
`/assets/vex/media/`; names match the candidates in the site's `media()` helper.
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops

# Recording folder name -> output GIF name. Keeping the mapping explicit means a
# renamed recording cannot silently ship the wrong file.
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

# Short clips keep the page light; a demo that is not a transition is a still.
MAX_BYTES = 3_000_000


def read_manifest(source: Path, name: str) -> tuple[list[Image.Image], list[int]]:
    manifest = json.loads((source / f"{name}-frames.json").read_text(encoding="utf-8"))
    if not manifest:
        raise ValueError(f"{name}: the recording contains no frames.")
    frames: list[Image.Image] = []
    durations: list[int] = []
    for row in manifest:
        path = (source / row["file"]).resolve()
        if not path.is_relative_to(source.resolve()):
            raise ValueError(f"{name}: a frame path escapes the capture directory.")
        duration = row["durationMs"]
        if not isinstance(duration, int) or duration < 10 or duration % 10:
            raise ValueError(f"{name}: GIF frame durations must be positive 10 ms multiples.")
        with Image.open(path) as image:
            frame = image.convert("RGB")
        if frames and frame.size != frames[0].size:
            raise ValueError(f"{name}: all frames must have the same dimensions.")
        frames.append(frame)
        durations.append(duration)
    return frames, durations


def shared_palette(frames: list[Image.Image]) -> Image.Image:
    """One palette across the whole clip keeps Chinese text and quiet surfaces stable."""
    tile_w, tile_h = 240, 152
    sheet = Image.new("RGB", (tile_w * len(frames), tile_h))
    for index, frame in enumerate(frames):
        sheet.paste(frame.resize((tile_w, tile_h)), (index * tile_w, 0))
    return sheet.quantize(colors=256)


def encode(frames: list[Image.Image], durations: list[int], destination: Path) -> None:
    palette = shared_palette(frames)
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
            raise ValueError(f"{destination.name}: encoded size does not match the capture.")
        if elapsed != sum(durations):
            raise ValueError(f"{destination.name}: encoded duration does not match.")
        expected = indexed[-1].convert("RGB")
        if ImageChops.difference(recorded.convert("RGB"), expected).getbbox():
            raise ValueError(f"{destination.name}: the final frame differs from the capture.")
        print(f"{destination.name}: {recorded.n_frames} frames, {elapsed / 1000:.2f}s, "
              f"{destination.stat().st_size:,} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="VEX_CAPTURE_DIR from the native test")
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
        frames, durations = read_manifest(args.source, name)
        destination = args.output / gif
        encode(frames, durations, destination)
        if destination.stat().st_size > MAX_BYTES:
            print(f"  warning: {gif} exceeds {MAX_BYTES:,} bytes; "
                  "consider shorter holds or fewer palette colours")
    if missing:
        print("not recorded (skipped): " + ", ".join(missing))


if __name__ == "__main__":
    main()
