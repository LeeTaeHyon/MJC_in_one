from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any, Iterable

from dotenv import load_dotenv

import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore


def load_env() -> None:
    # Load .env if present; environment variables still take precedence.
    load_dotenv(override=False)


def get_project_id() -> str:
    pid = (os.getenv("FIREBASE_PROJECT_ID") or "").strip()
    if not pid:
        raise SystemExit(
            "Missing FIREBASE_PROJECT_ID. Set it in environment or .env."
        )
    return pid


def init_firebase() -> None:
    if firebase_admin._apps:
        return
    # ApplicationDefault uses GOOGLE_APPLICATION_CREDENTIALS if set.
    firebase_admin.initialize_app(credentials.ApplicationDefault())


def get_db() -> firestore.Client:
    init_firebase()
    # Project is resolved from credentials / default app.
    # We still require FIREBASE_PROJECT_ID for sanity checks in scripts.
    _ = get_project_id()
    return firestore.client()


def read_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def normalize_doc_id(value: str) -> str:
    v = value.strip().lower()
    out = []
    for ch in v:
        if ch.isalnum():
            out.append(ch)
        else:
            out.append("_")
    doc_id = "".join(out).strip("_")
    return doc_id[:150] if len(doc_id) > 150 else doc_id


@dataclass(frozen=True)
class UpsertResult:
    created: int
    updated: int
    unchanged: int


def chunks(items: list[Any], size: int) -> Iterable[list[Any]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def print_header(title: str) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)
