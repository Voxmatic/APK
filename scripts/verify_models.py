#!/usr/bin/env python3
"""Verify every installed model against assets/models/manifest.json."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "assets" / "models"
MANIFEST = MODELS / "manifest.json"


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures = []
    for model in manifest["models"]:
        path = MODELS / model["filename"]
        if not path.exists():
            print(f"MISSING  {model['id']:24} {model['group']}")
            if model.get("required"):
                failures.append(model["id"])
            continue
        size = path.stat().st_size
        expected_size = model.get("size_bytes")
        size_ok = expected_size is None or size == int(expected_size)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expected_hash = model.get("sha256")
        hash_ok = not expected_hash or digest == str(expected_hash).lower()
        status = "OK" if size_ok and hash_ok else "CORRUPT"
        print(f"{status:8} {model['id']:24} size={size} sha256={digest}")
        if status == "CORRUPT":
            failures.append(model["id"])
    print(f"\n{len(failures)} failure(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
