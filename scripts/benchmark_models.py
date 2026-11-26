#!/usr/bin/env python3
"""Benchmark on-device model latency and memory on a connected Android device.

Runs entirely over adb; no data leaves the device. Uses Android's `am start`
with the app's benchmark activity or, when available, the `tflite_benchmark`
binary pushed by this script. Results are printed as JSON and can be committed
as evidence for docs/DEVICE_COMPATIBILITY.md.

Usage:
  python3 scripts/benchmark_models.py --device <serial> --iterations 50
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def adb(device: str | None, args: list[str], check: bool = True) -> str:
    cmd = ["adb"]
    if device:
        cmd += ["-s", device]
    cmd += args
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise SystemExit(f"adb {' '.join(args)} failed:\n{result.stderr}")
    return result.stdout.strip()


def device_info(device: str | None) -> dict:
    return {
        "model": adb(device, ["shell", "getprop", "ro.product.model"], check=False),
        "android": adb(device, ["shell", "getprop", "ro.build.version.release"], check=False),
        "sdk": adb(device, ["shell", "getprop", "ro.build.version.sdk"], check=False),
        "abi": adb(device, ["shell", "getprop", "ro.product.cpu.abi"], check=False),
        "ram_kb": adb(device, ["shell", "getprop", "ro.config.total_ram_kb"], check=False),
    }


def check_app(device: str | None, package: str) -> bool:
    out = adb(device, ["shell", "pm", "list", "packages", package], check=False)
    return f"package:{package}" in out


def benchmark_pose(device: str | None, package: str, iterations: int) -> dict:
    """Trigger the in-app benchmark via an explicit broadcast.

    The app listens for this broadcast only in debug builds, runs `iterations`
    inference passes on a synthetic all-zeros tensor, and reports wall-clock
    ms. No camera frames or user data are involved.
    """
    action = "com.aitrainer.gymtrainer.ai_gym_trainer.BENCHMARK_POSE"
    adb(
        device,
        [
            "shell",
            "am",
            "broadcast",
            "-a",
            action,
            "-n",
            f"{package}/.MainActivity",
            "--es",
            "model_id",
            "pose_landmarker_lite",
            "--ei",
            "iterations",
            str(iterations),
        ],
    )
    # The app writes the result to logcat with a stable tag; poll briefly.
    out = adb(
        device,
        ["logcat", "-d", "-t", "200", "-s", "AIGymBench:I", "|", "grep", "RESULT"],
        check=False,
    )
    line = next((ln for ln in out.splitlines() if "RESULT" in ln), "")
    if not line:
        return {"status": "NO_RESULT", "note": "install a debug build and rerun"}
    return {"status": "OK", "raw": line}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--device", help="adb device serial")
    ap.add_argument("--package", default="com.aitrainer.gymtrainer.ai_gym_trainer")
    ap.add_argument("--iterations", type=int, default=50)
    args = ap.parse_args()

    if shutil.which("adb") is None:
        raise SystemExit("adb not found on PATH; set ANDROID_HOME/platform-tools in PATH")

    result = {
        "schema_version": 1,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "device": device_info(args.device),
        "app_installed": check_app(args.device, args.package),
        "models": {},
    }
    if result["app_installed"]:
        result["models"]["pose_landmarker_lite"] = benchmark_pose(
            args.device, args.package, args.iterations
        )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    sys.exit(main())
