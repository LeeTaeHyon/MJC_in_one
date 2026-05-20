from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone

from common import get_db, load_env, print_header, read_json


DEFAULT_SLUGS_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "app",
    "assets",
    "data",
    "department_slugs.json",
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", default=DEFAULT_SLUGS_PATH)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_env()
    data = read_json(args.path)
    mapping: dict[str, str] = data.get("by_display_name") or {}
    if not mapping:
        raise SystemExit("by_display_name is empty")

    print_header("Seed: community_notices/*/meta/info")
    db = get_db()
    now = datetime.now(timezone.utc).isoformat()
    count = 0

    for display_name, slug in sorted(mapping.items(), key=lambda x: x[1]):
        meta_ref = (
            db.collection("community_notices")
            .document(slug)
            .collection("meta")
            .document("info")
        )
        payload = {
            "display_name": display_name,
            "active": True,
            "post_count": 0,
            "updated_at": now,
        }
        if args.dry_run:
            print(f"[dry-run] {meta_ref.path} <- {display_name}")
        else:
            meta_ref.set(payload, merge=True)
        count += 1

    print(f"Done: {count} boards")


if __name__ == "__main__":
    main()
