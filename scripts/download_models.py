#!/usr/bin/env python3
"""Controlled, resumable, hash-verified model downloader.

Models are NEVER downloaded automatically during a Flutter build. Run explicitly:

    python3 scripts/download_models.py --group pose
    python3 scripts/download_models.py --group llm
    python3 scripts/download_models.py --group all

The official source URL and expected SHA-256/size come from assets/models/manifest.json.
Only stdlib is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "models" / "manifest.json"
MODELS_DIR = ROOT / "assets" / "models"
LOG = ROOT / "docs" / "model_downloads.log"
CHUNK = 1024 * 1024


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(4 * CHUNK), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest() -> dict:
    with MANIFEST.open(encoding="utf-8") as f:
        return json.load(f)


def disk_free_gb(path: Path) -> float:
    usage = shutil.disk_usage(str(path))
    return usage.free / (1024 ** 3)


def log(message: str) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(f"{datetime.now(timezone.utc).isoformat()} {message}\n")
    print(message, flush=True)


def verify(model: dict, path: Path) -> bool:
    expected_size = model.get("size_bytes")
    if expected_size is not None and path.stat().st_size != int(expected_size):
        log(f"FAIL {model['id']}: size {path.stat().st_size} != expected {expected_size}")
        return False
    expected_hash = model.get("sha256")
    if expected_hash:
        actual = sha256(path)
        if actual.lower() != str(expected_hash).lower():
            log(f"FAIL {model['id']}: sha256 {actual} != expected {expected_hash}")
            return False
    log(f"OK {model['id']}: size={path.stat().st_size} sha256={sha256(path)}")
    return True


def download(model: dict, force: bool, assume_yes: bool) -> bool:
    dest = MODELS_DIR / model["filename"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and not force:
        log(f"FOUND {model['id']} at {dest}")
        if verify(model, dest):
            return True
        log(f"Corrupt existing file; re-downloading {model['id']}")
        dest.unlink()

    url = model["url"]
    if not url.startswith("https://"):
        log(f"REJECT {model['id']}: source is not HTTPS ({url})")
        return False

    tmp = dest.with_suffix(dest.suffix + ".part")
    existing = tmp.stat().st_size if tmp.exists() else 0
    expected = model.get("size_bytes")
    if expected is not None and existing > int(expected):
        tmp.unlink()
        existing = 0

    headers = {"User-Agent": "ai-gym-trainer-model-downloader/1.0"}
    if existing:
        headers["Range"] = f"bytes={existing}-"
    log(f"GET {model['id']} from {url} (resume at {existing} bytes)")
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=60) as response:
            status = response.status
            if existing and status != 206:
                log(f"Server ignored Range for {model['id']} (status {status}); restarting")
                existing = 0
            mode = "ab" if existing and status == 206 else "wb"
            with tmp.open(mode) as out:
                while True:
                    chunk = response.read(CHUNK)
                    if not chunk:
                        break
                    out.write(chunk)
    except Exception as exc:  # noqa: BLE001 - downloader must never crash silently
        log(f"DOWNLOAD ERROR {model['id']}: {exc}. Partial file kept at {tmp}")
        return False

    if not verify(model, tmp):
        log(f"REJECT {model['id']}: corrupt/incomplete download kept as {tmp} for inspection")
        return False
    os.replace(tmp, dest)
    log(f"INSTALLED {model['id']} -> {dest}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", default="pose", help="pose|pose-full|exercise|llm|speech|voice|all")
    parser.add_argument("--force", action="store_true", help="Re-verify and re-download if needed")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation for large downloads")
    args = parser.parse_args()

    manifest = load_manifest()
    models = [m for m in manifest["models"] if m["group"] == args.group]
    if args.group == "all":
        models = [m for m in manifest["models"] if m.get("sha256") or m.get("size_bytes")]
        total = sum(int(m.get("size_bytes") or 0) for m in models)
        free = disk_free_gb(MODELS_DIR)
        print(f"Planned download: {len(models)} models, {total / 1024**2:.1f} MiB")
        print(f"Free space at {MODELS_DIR}: {free:.2f} GiB")
        if free < (total / 1024**3) * 2:
            print("ABORT: insufficient disk space (need at least 2x download size).")
            return 2
        if not args.yes and input("Proceed? [y/N] ").strip().lower() not in {"y", "yes"}:
            print("Cancelled.")
            return 1

    if not models:
        print(f"No approved downloadable models for group '{args.group}'.")
        print("Note: exercise/TCN weights must be trained locally; speech/voice packs require per-model licence review.")
        return 0

    required = [m for m in models if m.get("required")]
    needed = sum(
        int(m.get("size_bytes") or 0)
        for m in required
        if not (MODELS_DIR / m["filename"]).exists()
    )
    if needed:
        free = disk_free_gb(MODELS_DIR)
        if free < needed / 1024**3:
            print(f"ABORT: need {needed / 1024**2:.1f} MiB but only {free:.2f} GiB free.")
            return 2

    failures = [m["id"] for m in models if not download(m, args.force, args.yes)]
    if failures:
        print("Failed: " + ", ".join(failures))
        return 1
    print("All requested models verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
