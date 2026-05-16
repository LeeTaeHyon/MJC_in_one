from __future__ import annotations

import argparse
import subprocess
import sys

from common import print_header


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--prune-missing", action="store_true")
    parser.add_argument("--only", default="", help="comma-separated: campus,departments,shuttle,foodcourt,timetable")
    parser.add_argument(
        "--timetable-csv",
        default="",
        help="Required when --only includes timetable: path to CSV for upload_timetable.py",
    )
    parser.add_argument(
        "--timetable-replace",
        action="store_true",
        help="When uploading timetable, delete existing timetable_official docs first",
    )
    args = parser.parse_args()

    print_header("Sync from local")
    only = {s.strip() for s in (args.only or "").split(",") if s.strip()}
    if not only:
        only = {"campus", "departments", "shuttle", "foodcourt"}

    steps = [
        ("campus", ["tools/upload/upload_campus.py"]),
        ("departments", ["tools/upload/upload_departments.py"]),
        ("shuttle", ["tools/upload/upload_shuttle.py"]),
        ("foodcourt", ["tools/upload/upload_foodcourt.py"]),
        ("timetable", ["tools/upload/upload_timetable.py"]),
    ]

    base_flags = []
    if args.validate:
        base_flags.append("--validate")
    if args.dry_run:
        base_flags.append("--dry-run")

    for name, cmd in steps:
        if name not in only:
            continue
        flags = list(base_flags)
        if name in {"shuttle", "foodcourt"} and args.prune_missing:
            flags.append("--prune-missing")
        if name == "timetable":
            csv_path = (args.timetable_csv or "").strip()
            if not csv_path:
                raise SystemExit(
                    "sync_from_local: --timetable-csv is required when syncing timetable."
                )
            flags.extend(["--path", csv_path])
            if args.timetable_replace:
                flags.append("--replace")
        full = [sys.executable, *cmd, *flags]
        print("\n$ " + " ".join(full))
        subprocess.check_call(full)


if __name__ == "__main__":
    main()

