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
    "shuttle.csv",
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
    required = {"stop_name", "depart_time", "weekday", "arrive_stop", "travel_min"}
    for i, r in enumerate(rows):
        missing = required - set(r.keys())
        if missing:
            raise SystemExit(f"shuttle.csv row {i}: missing columns {sorted(missing)}")
        if not (r["stop_name"] or "").strip():
            raise SystemExit(f"shuttle.csv row {i}: stop_name empty")
        if not (r["depart_time"] or "").strip():
            raise SystemExit(f"shuttle.csv row {i}: depart_time empty")


def _doc_id(r: Dict[str, str]) -> str:
    key = "|".join(
        [
            (r.get("weekday") or "").strip(),
            (r.get("depart_time") or "").strip(),
            (r.get("stop_name") or "").strip(),
            (r.get("arrive_stop") or "").strip(),
        ]
    )
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

    print_header("Upload: shuttle_schedule/*")
    db = get_db()
    col = db.collection("shuttle_schedule")

    payloads: List[Tuple[str, Dict[str, Any]]] = []
    for r in rows:
        doc_id = _doc_id(r)
        payloads.append(
            (
                doc_id,
                {
                    "stop_name": (r.get("stop_name") or "").strip(),
                    "depart_time": (r.get("depart_time") or "").strip(),
                    "weekday": (r.get("weekday") or "").strip(),
                    "arrive_stop": (r.get("arrive_stop") or "").strip(),
                    "travel_min": int((r.get("travel_min") or "0").strip() or "0"),
                },
            )
        )

    if args.dry_run:
        print(f"[dry-run] would upsert {len(payloads)} docs into shuttle_schedule")
        if payloads:
            sample = payloads[:5]
            print("[dry-run] sample ids:", ", ".join([d for d, _ in sample]))
        if args.prune_missing:
            print("[dry-run] would prune missing docs (scan collection)")
        return

    # Upsert in batches
    batch_size = 450
    for group in chunks(payloads, batch_size):
        batch = db.batch()
        for doc_id, data in group:
            batch.set(col.document(doc_id), data)
        batch.commit()
    print(f"OK upserted {len(payloads)} docs into shuttle_schedule")

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
        print(f"OK pruned {len(to_delete)} docs from shuttle_schedule")


if __name__ == "__main__":
    main()

