from __future__ import annotations

import argparse
import os
from typing import Any, Dict

from common import get_db, load_env, print_header, read_json


DEFAULT_JSON_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "app",
    "assets",
    "data",
    "campus_buildings.json",
)


def _validate(data: Dict[str, Any]) -> None:
    mc = data.get("mapCenter")
    if not isinstance(mc, dict):
        raise SystemExit("campus_buildings.json: `mapCenter` must be object")
    if not isinstance(mc.get("lat"), (int, float)) or not isinstance(
        mc.get("lng"), (int, float)
    ):
        raise SystemExit("campus_buildings.json: mapCenter.lat/lng must be numbers")

    buildings = data.get("buildings")
    if not isinstance(buildings, list) or not buildings:
        raise SystemExit("campus_buildings.json: `buildings` must be non-empty list")

    aliases = data.get("aliases")
    if aliases is None or not isinstance(aliases, dict):
        raise SystemExit("campus_buildings.json: `aliases` must be object")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", default=DEFAULT_JSON_PATH)
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_env()
    data = read_json(args.path)
    if args.validate:
        _validate(data)

    print_header("Upload: config/campus_map")
    db = get_db()
    ref = db.collection("config").document("campus_map")

    buildings_count = len(data.get("buildings", []) or [])
    aliases_count = len(data.get("aliases", {}) or {})
    if args.dry_run:
        print(f"[dry-run] would set {ref.path}")
        print(f"[dry-run] buildings={buildings_count} aliases={aliases_count}")
        return

    ref.set(data)
    print(f"OK set {ref.path} (buildings={buildings_count}, aliases={aliases_count})")


if __name__ == "__main__":
    main()

