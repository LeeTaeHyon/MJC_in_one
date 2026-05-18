from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import subprocess
from typing import Any, Dict, List, Optional, Tuple

from common import chunks, get_db, load_env, print_header

# Same regex as app `TimetableSlotParser._slotPattern`.
_SLOT_RE = re.compile(
    r"(월|화|수|목|금|토)\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*\(\s*([^)]*)\s*\)"
)

_WEEKDAY = {"월": 1, "화": 2, "수": 3, "목": 4, "금": 5, "토": 6}

# Same marker as app `ParsedCourseOffering.remoteExamScheduleMarker`.
_REMOTE_EXAM_MARKER = "원격시험 배정시간"


def _is_remote_exam_only(raw_tt: str) -> bool:
    return _REMOTE_EXAM_MARKER in raw_tt


def _read_csv_bytes(path: str) -> str:
    with open(path, "rb") as f:
        raw = f.read()
    try:
        return raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        return raw.decode("cp949")


def _parse_hm(s: str) -> Optional[int]:
    m = re.match(r"^(\d{1,2}):(\d{2})$", s.strip())
    if not m:
        return None
    h = int(m.group(1))
    mi = int(m.group(2))
    if h < 0 or h > 23 or mi < 0 or mi > 59:
        return None
    return h * 60 + mi


def _parse_slots(
    raw: str,
    course_name: str,
    offering_id: str,
    color_key: str,
) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for m in _SLOT_RE.finditer(raw):
        wd_ch = m.group(1)
        start_s = m.group(2)
        end_s = m.group(3)
        room = (m.group(4) or "").strip()
        wd = _WEEKDAY.get(wd_ch, 1)
        start = _parse_hm(start_s)
        end = _parse_hm(end_s)
        if start is None or end is None:
            continue
        if end <= start:
            continue
        out.append(
            {
                "weekday": wd,
                "startMinute": start,
                "endMinute": end,
                "room": room,
                "courseName": course_name,
                "offeringId": offering_id,
                "colorKey": color_key,
            }
        )
    return out


def _column_index(header_cells: List[str], keyword: str) -> Optional[int]:
    for i, h in enumerate(header_cells):
        if h.strip() == keyword:
            return i
    for i, h in enumerate(header_cells):
        if keyword in h:
            return i
    return None


def _split_rows(text: str) -> List[List[str]]:
    """
    Split CSV/TSV into rows.

    Excel exports sometimes use commas, semicolons, or tabs depending on locale.
    We sniff a delimiter first, then fall back to comma.
    """
    sample = text[:4096]
    dialect: Optional[csv.Dialect] = None
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=[",", ";", "\t", "|"])
    except Exception:
        dialect = None

    f = io.StringIO(text)
    reader = csv.reader(f, dialect=dialect) if dialect else csv.reader(f)
    return [r for r in reader]


def _row_looks_like_header(row: List[str]) -> bool:
    cells = [c.strip() for c in row if (c or "").strip()]
    if len(cells) < 5:
        return False
    joined = "\u0001".join(cells)
    return ("과목명" in joined) and ("시간표" in joined)


def _parse_offering_rows_from_matrix(
    header: List[str],
    data_rows: List[List[str]],
) -> List[Dict[str, str]]:
    col_course = _column_index(header, "과목명")
    col_time = _column_index(header, "시간표")
    if col_course is None or col_time is None:
        raise SystemExit(
            "CSV에서 필수 열을 찾지 못했습니다. 헤더에 «과목명», «시간표»가 있어야 합니다."
        )
    # Some exports use "과정부분" instead of "과정구분".
    col_cat = _column_index(header, "과정구분") or _column_index(header, "과정부분")
    col_dept = _column_index(header, "학과명")
    col_section = _column_index(header, "분반")
    col_prof = _column_index(header, "교수명")
    col_grade = _column_index(header, "학년")
    col_completion = _column_index(header, "이수구분명")
    col_credits = _column_index(header, "학점")

    def cell(row: List[str], idx: Optional[int]) -> str:
        if idx is None or idx >= len(row):
            return ""
        return (row[idx] or "").strip()

    last_cat = ""
    last_dept = ""
    out: List[Dict[str, str]] = []

    for row in data_rows:
        cat = cell(row, col_cat)
        if not cat:
            cat = last_cat
        else:
            last_cat = cat

        dept = cell(row, col_dept)
        if not dept:
            dept = last_dept
        else:
            last_dept = dept

        course_name = cell(row, col_course)
        timetable_raw = cell(row, col_time)
        if not course_name and not timetable_raw:
            continue

        out.append(
            {
                "courseCategory": cat,
                "department": dept,
                "courseName": course_name,
                "section": cell(row, col_section),
                "professor": cell(row, col_prof),
                "gradeYear": cell(row, col_grade),
                "completionType": cell(row, col_completion),
                "credits": cell(row, col_credits),
                "rawTimetableText": timetable_raw,
            }
        )
    return out


def _parse_csv(path: str) -> List[Dict[str, str]]:
    text = _read_csv_bytes(path)
    rows = _split_rows(text)
    if not rows:
        raise SystemExit("CSV가 비어 있습니다.")

    header_idx = -1
    max_scan = 120 if len(rows) > 120 else len(rows)
    for i in range(max_scan):
        if _row_looks_like_header(rows[i]):
            header_idx = i
            break
    if header_idx < 0:
        raise SystemExit(
            "CSV에서 헤더(과목명·시간표)를 찾지 못했습니다. 표 위쪽의 제목/안내문 줄이 포함돼 있다면,"
            " 과목명이 있는 행부터 시작하도록 CSV를 저장하거나, 현재 스크립트 기준으로는 헤더 행이 포함돼 있어야 합니다."
        )

    header = rows[header_idx]
    data_rows = rows[header_idx + 1 :]
    return _parse_offering_rows_from_matrix(header, data_rows)


def _dart_offering_ids(rows_for_ids: List[Tuple[str, str, str, str]]) -> List[str]:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    script = os.path.join("tools", "upload", "offering_id_batch.dart")
    script_abs = os.path.join(repo_root, script)
    if not os.path.isfile(script_abs):
        raise SystemExit(f"Missing {script_abs}")

    lines = ["\t".join(parts) for parts in rows_for_ids]
    proc = subprocess.run(
        ["dart", "run", script],
        input=("\n".join(lines) + "\n").encode("utf-8"),
        cwd=repo_root,
        capture_output=True,
    )
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="replace")
        raise SystemExit(f"dart offering_id_batch failed ({proc.returncode}): {err}")

    out = [ln.strip() for ln in proc.stdout.decode().splitlines() if ln.strip()]
    if len(out) != len(rows_for_ids):
        raise SystemExit(
            f"offering id count mismatch: dart returned {len(out)}, expected {len(rows_for_ids)}"
        )
    return out


def _build_payloads(rows: List[Dict[str, str]]) -> Tuple[List[str], List[Dict[str, Any]]]:
    """Skip rows with empty course name or timetable.

    Rows with only «원격시험 배정시간» (P/NP: no weekly slots, no exam) are kept
    with empty slots — same as app [ParsedCourseOffering.isPassNonPassRemote].
    """
    kept: List[Dict[str, str]] = []
    quads: List[Tuple[str, str, str, str]] = []

    for r in rows:
        dept = r["department"].strip()
        course_name = r["courseName"].strip()
        section = r["section"].strip()
        prof = r["professor"].strip()
        raw_tt = r["rawTimetableText"].strip()
        if not course_name or not raw_tt:
            continue
        color_key = f"{course_name}|{section}"
        probe_slots = _parse_slots(
            raw=raw_tt,
            course_name=course_name,
            offering_id="probe",
            color_key=color_key,
        )
        if not probe_slots and not _is_remote_exam_only(raw_tt):
            continue
        kept.append(r)
        quads.append((dept, course_name, section, prof))

    if not quads:
        return [], []

    ids = _dart_offering_ids(quads)

    doc_ids: List[str] = []
    payloads: List[Dict[str, Any]] = []

    for r, oid in zip(kept, ids):
        dept = r["department"].strip()
        course_name = r["courseName"].strip()
        section = r["section"].strip()
        prof = r["professor"].strip()
        raw_tt = r["rawTimetableText"].strip()
        color_key = f"{course_name}|{section}"
        slots = _parse_slots(
            raw=raw_tt,
            course_name=course_name,
            offering_id=oid,
            color_key=color_key,
        )

        payload = {
            "offeringId": oid,
            "courseCategory": r["courseCategory"],
            "department": dept,
            "courseName": course_name,
            "section": section,
            "professor": prof,
            "gradeYear": r["gradeYear"],
            "completionType": r["completionType"],
            "credits": r["credits"],
            "rawTimetableText": raw_tt,
            "slots": slots,
        }
        doc_ids.append(oid)
        payloads.append(payload)

    return doc_ids, payloads


def _delete_collection(db: Any, coll_name: str, dry_run: bool) -> int:
    col = db.collection(coll_name)
    deleted = 0
    refs = [snap.reference for snap in col.stream()]
    if dry_run:
        return len(refs)
    for batch_refs in chunks(refs, 450):
        bulk = db.batch()
        for ref in batch_refs:
            bulk.delete(ref)
        bulk.commit()
        deleted += len(batch_refs)
    return deleted


def _upload(db: Any, coll_name: str, pairs: List[Tuple[str, Dict[str, Any]]], dry_run: bool) -> None:
    col = db.collection(coll_name)
    if dry_run:
        return
    for chunk_pairs in chunks(pairs, 400):
        bulk = db.batch()
        for doc_id, data in chunk_pairs:
            bulk.set(col.document(doc_id), data)
        bulk.commit()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "CSV «전체 강의시간표» → Firestore collection `timetable_official`. "
            "헤더는 엑셀과 동일하게 «과목명», «시간표» 필수, 나머지 열은 앱 파서와 동일."
        )
    )
    parser.add_argument("--path", required=True, help="Path to CSV file")
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Delete ALL existing docs in timetable_official before upload",
    )
    parser.add_argument("--validate", action="store_true", help="Parse only; exit on error")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--print-sample",
        type=int,
        default=0,
        metavar="N",
        help="Print first N offerings as JSON lines",
    )
    args = parser.parse_args()

    load_env()
    rows = _parse_csv(args.path)
    if args.validate:
        doc_ids, payloads = _build_payloads(rows)
        print(f"OK: {len(payloads)} offerings parsed (from {len(rows)} table rows)")
        if args.print_sample > 0:
            for p in payloads[: args.print_sample]:
                print(json.dumps(p, ensure_ascii=False))
        return

    print_header("Upload: timetable_official/* (CSV)")
    db = get_db()
    coll = "timetable_official"

    doc_ids, payloads = _build_payloads(rows)
    if not payloads:
        raise SystemExit(
            "업로드할 강의가 없습니다. «과목명»과 «시간표» 형식(월~토 슬롯)을 확인하세요."
        )

    pairs = list(zip(doc_ids, payloads))
    if args.dry_run:
        print(f"Would upload {len(pairs)} docs to {coll}.")
        if args.replace:
            n = _delete_collection(db, coll, dry_run=True)
            print(f"Would delete existing docs first (~{n} docs).")
        if args.print_sample > 0:
            for _, data in pairs[: args.print_sample]:
                print(json.dumps(data, ensure_ascii=False))
        return

    removed = 0
    if args.replace:
        removed = _delete_collection(db, coll, dry_run=False)
        print(f"Deleted {removed} existing doc(s) in {coll}.")

    _upload(db, coll, pairs, dry_run=False)
    print(f"Wrote {len(pairs)} doc(s) to {coll}.")


if __name__ == "__main__":
    main()
