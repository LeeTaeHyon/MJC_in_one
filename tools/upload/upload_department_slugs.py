from __future__ import annotations

import argparse
import os

from common import get_db, load_env, print_header, read_json


DEFAULT_JSON_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "app",
    "assets",
    "data",
    "department_slugs.json",
)


def _validate(data: dict) -> None:
    if not isinstance(data.get("version"), int):
        raise SystemExit("department_slugs.json: `version` must be int")
    mapping = data.get("by_display_name")
    if not isinstance(mapping, dict) or not mapping:
        raise SystemExit("department_slugs.json: `by_display_name` must be non-empty dict")


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

    print_header("Upload: config/department_slugs")
    ref = get_db().collection("config").document("department_slugs")

    if args.dry_run:
        print(f"[dry-run] would set {ref.path}")
        print(f"[dry-run] version={data.get('version')} count={len(data.get('by_display_name', {}))}")
        return

    ref.set(data)
    print(f"OK set {ref.path}")


if __name__ == "__main__":
    main()
