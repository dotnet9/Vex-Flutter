"""Exercise the documentation encoder without a Flutter build."""

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from build_media import build_media


class MediaBuildTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "captures"
        self.source.mkdir()
        self.output = self.root / "output"
        self.manifest = []
        for index in range(6):
            name = f"{index}.png"
            Image.new("RGB", (64, 48), (index * 40, 80, 120)).save(self.source / name)
            self.manifest.append({"file": name, "durationMs": 100 + index * 10})
        for name in ("workspace", "source-preview", "mindmap-dark"):
            Image.new("RGB", (64, 48), "white").save(self.source / f"{name}.png")
        self.write_manifest()

    def write_manifest(self):
        (self.source / "guide-frames.json").write_text(json.dumps(self.manifest))

    def test_encoded_duration_dimensions_loop_and_stills(self):
        with contextlib.redirect_stdout(io.StringIO()):
            build_media(self.source, self.output)
        with Image.open(self.output / "windows-guide.gif") as image:
            self.assertEqual(image.n_frames, 6)
            self.assertEqual(image.size, (64, 48))
            self.assertEqual(image.info["loop"], 0)
            duration = 0
            for index in range(image.n_frames):
                image.seek(index)
                duration += image.info["duration"]
            self.assertEqual(duration, 750)
        self.assertEqual(len(list(self.output.glob("*.png"))), 3)

    def test_rejects_escaped_frame_paths(self):
        self.manifest[0]["file"] = "../outside.png"
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "escapes"):
            build_media(self.source, self.output)

    def test_rejects_unrepresentable_durations(self):
        for duration in (0, -10, 15):
            with self.subTest(duration=duration):
                self.manifest[0]["durationMs"] = duration
                self.write_manifest()
                with self.assertRaisesRegex(ValueError, "10 ms"):
                    build_media(self.source, self.output)

    def test_rejects_mixed_frame_sizes(self):
        Image.new("RGB", (60, 40)).save(self.source / "1.png")
        with self.assertRaisesRegex(ValueError, "same dimensions"):
            build_media(self.source, self.output)

    def test_rejects_empty_recordings(self):
        self.manifest.clear()
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "no frames"):
            build_media(self.source, self.output)
