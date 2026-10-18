"""Encode native Flutter README captures without adding decorative UI."""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops


def build_media(source: Path, destination: Path) -> None:
    manifest = json.loads((source / "guide-frames.json").read_text(encoding="utf-8"))
    if not manifest:
        raise ValueError("The recording contains no frames.")
    frames = []
    durations = []
    for row in manifest:
        path = (source / row["file"]).resolve()
        if not path.is_relative_to(source.resolve()):
            raise ValueError("A frame path escapes the capture directory.")
        duration = row["durationMs"]
        if not isinstance(duration, int) or duration < 10 or duration % 10:
            raise ValueError("GIF frame durations must be positive 10 ms multiples.")
        with Image.open(path) as image:
            frame = image.convert("RGB")
        if frames and frame.size != frames[0].size:
            raise ValueError("All recording frames must have the same dimensions.")
        frames.append(frame)
        durations.append(duration)

    destination.mkdir(parents=True, exist_ok=True)
    # One shared palette keeps Chinese text and quiet surface colors stable.
    palette_source = Image.new("RGB", (280 * len(frames), 190))
    for index, frame in enumerate(frames):
        palette_source.paste(frame.resize((280, 190)), (index * 280, 0))
    palette = palette_source.quantize(colors=256)
    indexed = [
        frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames
    ]
    gif = destination / "windows-guide.gif"
    indexed[0].save(
        gif,
        save_all=True,
        append_images=indexed[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=1,
    )
    with Image.open(gif) as recorded:
        elapsed = 0
        for index in range(recorded.n_frames):
            recorded.seek(index)
            elapsed += recorded.info["duration"]
        if recorded.size != frames[0].size or elapsed != sum(durations):
            raise ValueError("Encoded recording size or duration does not match.")
        if recorded.n_frames < 6:
            raise ValueError("The guide must include all six steps.")
        # Verify that the final restored workspace was not lost by GIF disposal.
        expected = indexed[-1].convert("RGB")
        if ImageChops.difference(recorded.convert("RGB"), expected).getbbox():
            raise ValueError("The encoded final frame differs from the capture.")
        print(f"{gif}: {recorded.n_frames} frames, {elapsed / 1000:.2f}s")

    for name in ("workspace", "source-preview", "mindmap-dark"):
        with Image.open(source / f"{name}.png") as image:
            image.save(destination / f"{name}.png", optimize=True)
    for path in sorted(destination.glob("*.png")) + [gif]:
        print(f"{path.name}: {path.stat().st_size:,} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="VEX_CAPTURE_DIR from the native test")
    parser.add_argument(
        "--output", type=Path, default=Path(__file__).resolve().parents[2] / "docs/media"
    )
    args = parser.parse_args()
    build_media(args.source, args.output)


if __name__ == "__main__":
    main()
