from __future__ import annotations

import argparse
import csv
import io
import os
from typing import Any, Dict, List, Tuple

from common import chunks, get_db, load_env, normalize_doc_id, print_header


DEFAULT_CSV_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "app",
    "assets",
    "data",
    "foodcourt.csv",
)


def _read_csv_rows(path: str) -> List[Dict[str, str]]:
    with open(path, "rb") as f:
        raw = f.read()
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("cp949")
    reader = csv.DictReader(io.StringIO(text))
    return [dict(r) for r in reader]


def _validate(rows: List[Dict[str, str]]) -> None:
    required = {"shop", "menu", "price"}
    for i, r in enumerate(rows):
        missing = required - set(r.keys())
        if missing:
            raise SystemExit(f"foodcourt.csv row {i}: missing columns {sorted(missing)}")
        if not (r["shop"] or "").strip():
            raise SystemExit(f"foodcourt.csv row {i}: shop empty")
        if not (r["menu"] or "").strip():
            raise SystemExit(f"foodcourt.csv row {i}: menu empty")


def _doc_id(r: Dict[str, str]) -> str:
    key = "|".join([(r.get("shop") or "").strip(), (r.get("menu") or "").strip()])
    doc_id = normalize_doc_id(key)
    return doc_id or "row"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", default=DEFAULT_CSV_PATH)
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--prune-missing",
        action="store_true",
        help="Delete Firestore docs that are not present in local csv",
    )
    args = parser.parse_args()

    load_env()
    rows = _read_csv_rows(args.path)
    if args.validate:
        _validate(rows)

    print_header("Upload: foodcourt_menu/*")
    db = get_db()
    col = db.collection("foodcourt_menu")

    payloads: List[Tuple[str, Dict[str, Any]]] = []
    for r in rows:
        doc_id = _doc_id(r)
        payloads.append(
            (
                doc_id,
                {
                    "shop": (r.get("shop") or "").strip(),
                    "menu": (r.get("menu") or "").strip(),
                    "price": int((r.get("price") or "0").strip() or "0"),
                },
            )
        )

    if args.dry_run:
        print(f"[dry-run] would upsert {len(payloads)} docs into foodcourt_menu")
        if payloads:
            sample = payloads[:5]
            print("[dry-run] sample ids:", ", ".join([d for d, _ in sample]))
        if args.prune_missing:
            print("[dry-run] would prune missing docs (scan collection)")
        return

    batch_size = 450
    for group in chunks(payloads, batch_size):
        batch = db.batch()
        for doc_id, data in group:
            batch.set(col.document(doc_id), data)
        batch.commit()
    print(f"OK upserted {len(payloads)} docs into foodcourt_menu")

    if args.prune_missing:
        keep = set([doc_id for doc_id, _ in payloads])
        to_delete = []
        for snap in col.stream():
            if snap.id not in keep:
                to_delete.append(snap.reference)
        for group in chunks(to_delete, 450):
            batch = db.batch()
            for ref in group:
                batch.delete(ref)
            batch.commit()
        print(f"OK pruned {len(to_delete)} docs from foodcourt_menu")


if __name__ == "__main__":
    main()

