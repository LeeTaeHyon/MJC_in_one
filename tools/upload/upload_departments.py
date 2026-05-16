from __future__ import annotations

import argparse
import os
from typing import Any, Dict, List

from common import get_db, load_env, print_header, read_json


DEFAULT_JSON_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "app",
    "assets",
    "data",
    "mjc_departments.json",
)


def _validate(data: Dict[str, Any]) -> None:
    if not isinstance(data.get("version"), int):
        raise SystemExit("departments.json: `version` must be int")
    if not isinstance(data.get("source"), str):
        raise SystemExit("departments.json: `source` must be string")
    deps = data.get("departments")
    if not isinstance(deps, list) or not deps:
        raise SystemExit("departments.json: `departments` must be non-empty list")


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

    print_header("Upload: config/departments")
    db = get_db()
    ref = db.collection("config").document("departments")

    if args.dry_run:
        print(f"[dry-run] would set {ref.path}")
        print(f"[dry-run] version={data.get('version')} count={len(data.get('departments', []))}")
        return

    ref.set(data)
    print(f"OK set {ref.path}")


if __name__ == "__main__":
    main()

