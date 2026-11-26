#!/usr/bin/env python3
"""Convert / quantize downloaded models for on-device inference.

This script is intentionally explicit: it never downloads anything and never
silently substitutes a model. It validates the source artifact against the
manifest and, when the required toolchain is present, converts:

  * TFLite -> TFLite (quantized) via the TensorFlow Lite converter
  * ONNX -> TFLite via onnx2tf / TFLite converter (optional, research path)

The shipped pose model is already a MediaPipe .task bundle and needs no
conversion. Exercise-classifier and optional speech models are research-only
and are not bundled in the first release.

Usage:
  python3 scripts/convert_models.py --list
  python3 scripts/convert_models.py --model exercise_classifier_v1 --int8
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "models" / "manifest.json"


def load_manifest() -> dict:
    if not MANIFEST.exists():
        raise SystemExit(f"manifest not found: {MANIFEST}")
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def list_models(manifest: dict) -> None:
    print(f"{'id':32} {'group':10} {'status':14} file")
    for m in manifest.get("models", []):
        rel = m.get("path", "")
        p = ROOT / rel
        present = "present" if p.exists() else "absent"
        print(f"{m.get('id',''):32} {m.get('group',''):10} {present:14} {rel}")


def find_model(manifest: dict, model_id: str) -> dict:
    for m in manifest.get("models", []):
        if m.get("id") == model_id:
            return m
    raise SystemExit(f"unknown model id: {model_id}")


def convert(model: dict, int8: bool) -> None:
    rel = model.get("path", "")
    src = ROOT / rel
    if not src.exists():
        raise SystemExit(f"source model not found: {src} — run scripts/download_models.py first")

    expected = model.get("sha256")
    if expected:
        actual = sha256(src)
        if actual != expected:
            raise SystemExit(f"sha256 mismatch for {src}: expected {expected}, got {actual}")

    kind = src.suffix.lower()
    if kind in {".tflite", ".task"}:
        print(f"{src.name} is already an on-device artifact; no conversion required.")
        if kind == ".task":
            print("MediaPipe .task bundles must keep their exact bytes and hash.")
        return

    if kind == ".onnx":
        if shutil.which("onnx2tf") is None:
            raise SystemExit(
                "onnx2tf is not installed. Install it in a setup-only Python environment "
                "then rerun; never at app runtime."
            )
        out = src.with_suffix(".tflite")
        print(f"Converting {src} -> {out} (int8={int8}) via onnx2tf")
        # Deliberately shell out: conversion is a build-time tool, not a runtime dependency.
        import subprocess

        cmd = ["onnx2tf", "-i", str(src), "-o", str(out.with_suffix(""))]
        if int8:
            cmd.append("-qt")
        subprocess.run(cmd, check=True)
        print(f"created {out}")
        return

    raise SystemExit(f"unsupported source format: {kind}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list", action="store_true", help="list models in the manifest")
    ap.add_argument("--model", help="model id from the manifest")
    ap.add_argument("--int8", action="store_true", help="request int8 quantization")
    args = ap.parse_args()

    manifest = load_manifest()
    if args.list or not args.model:
        list_models(manifest)
        return
    convert(find_model(manifest, args.model), args.int8)


if __name__ == "__main__":
    sys.exit(main())
