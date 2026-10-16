"""Copy the root brand sources into Flutter's asset boundary before building.

Edit only root logo.svg / logo.png / logo.ico. Generated copies are committed so
flutter run works immediately after cloning. CI uses --check to prevent drift.
"""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "apps/texweft/assets/brand"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    for name in ("logo.svg", "logo.png"):
        source = (ROOT / name).read_bytes()
        target = TARGET / name
        if args.check:
            if not target.exists() or target.read_bytes() != source:
                stale.append(name)
        else:
            TARGET.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source)
    if stale:
        parser.exit(1, f"Brand assets differ: {', '.join(stale)}. Run scripts/sync_brand_assets.py.\n")
    print("Brand assets match root sources." if args.check else "Updated Flutter brand assets.")


if __name__ == "__main__":
    main()
