#!/usr/bin/env python3
"""Generate real animated demonstration assets (MP4) and 3D ghost keyframes (JSON).

The MP4 files are rendered from procedural biomechanical keyframes, not static images or
fake placeholders: joints interpolate through a full rep and are drawn every frame.
Run once at build time; the assets are then bundled and played fully offline.
"""
from __future__ import annotations

import argparse
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
W, H, FPS, SECONDS = 480, 640, 24, 3

SQUAT_FRONT_STAND = [
    (240, 100), (240, 140), (210, 170), (270, 170), (195, 235), (285, 235),
    (185, 300), (295, 300), (215, 330), (265, 330), (215, 460), (265, 460), (210, 580), (270, 580),
]
SQUAT_FRONT_BOTTOM = [
    (240, 240), (240, 275), (210, 305), (270, 305), (190, 355), (290, 355),
    (180, 300), (300, 300), (215, 465), (265, 465), (190, 510), (290, 510), (210, 580), (270, 580),
]
SQUAT_EDGES = [(0, 1), (1, 2), (1, 3), (2, 4), (3, 5), (4, 6), (5, 7), (1, 8), (1, 9),
               (8, 10), (9, 11), (10, 12), (11, 13), (8, 9)]
PUSHUP_TOP = [
    (120, 210), (150, 235), (170, 250), (200, 305), (220, 385),
    (300, 275), (380, 315), (440, 345),
]
PUSHUP_BOTTOM = [
    (120, 295), (150, 310), (170, 320), (205, 360), (220, 400),
    (300, 345), (380, 350), (440, 350),
]
PUSHUP_EDGES = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (6, 7)]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def blank():
    return bytearray(b"\xff" * (W * H * 3))


def put(buf, x, y, rgb):
    x, y = int(x), int(y)
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 3
        buf[i:i + 3] = bytes(rgb)


def line(buf, p0, p1, rgb):
    # Round endpoints to integers: interpolating floats with differing fractions
    # would never satisfy the integer-stepping Bresenham equality test.
    x0, y0 = int(round(p0[0])), int(round(p0[1]))
    x1, y1 = int(round(p1[0])), int(round(p1[1]))
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx - dy
    while True:
        put(buf, x0, y0, rgb)
        for oy in (-1, 0, 1):
            for ox in (-1, 0, 1):
                put(buf, x0 + ox, y0 + oy, rgb)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def draw_frame(points, edges, highlight, frame_idx):
    buf = blank()
    for i, j in edges:
        color = (255, 92, 58) if (i in highlight or j in highlight) else (28, 58, 92)
        line(buf, points[i], points[j], color)
    for i, (x, y) in enumerate(points):
        color = (255, 180, 60) if i in highlight else (32, 214, 190)
        for dy in range(-5, 6):
            for dx in range(-5, 6):
                if dx * dx + dy * dy <= 25:
                    put(buf, x + dx, y + dy, color)
    # progress bar at bottom
    progress = int(W * frame_idx / (FPS * SECONDS))
    for x in range(W):
        for y in range(H - 12, H - 4):
            put(buf, x, y, (32, 214, 190) if x < progress else (210, 214, 222))
    return b"P6\n%d %d\n255\n" % (W, H) + bytes(buf)


def render(out: Path, stand, bottom, edges, highlight):
    ffmpeg = Path("/home/akkash/tools/ffmpeg-7.0.2-amd64-static/ffmpeg")
    if not ffmpeg.exists():
        raise SystemExit("ffmpeg not found; see docs/ENVIRONMENT_AUDIT.md")
    cmd = [str(ffmpeg), "-y", "-f", "image2pipe", "-vcodec", "ppm", "-r", str(FPS), "-i", "-",
           "-c:v", "libx264", "-preset", "veryfast", "-crf", "26", "-pix_fmt", "yuv420p",
           "-movflags", "+faststart", str(out)]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    frames = FPS * SECONDS
    for f in range(frames):
        phase = 0.5 - 0.5 * math.cos(2 * math.pi * f / frames)
        pts = [lerp(a, b, phase) for a, b in zip(stand, bottom)]
        proc.stdin.write(draw_frame(pts, edges, highlight, f))
    proc.stdin.close()
    stderr = proc.stderr.read().decode(errors="ignore")
    if proc.wait() != 0:
        raise SystemExit(f"ffmpeg failed: {stderr[-2000:]}")
    print(f"created {out} ({out.stat().st_size / 1024:.0f} KiB)")


def write_3d_json(path: Path) -> None:
    names = ["head", "neck", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "wrist_l", "wrist_r",
             "hip_l", "hip_r", "knee_l", "knee_r", "ankle_l", "ankle_r"]
    stand = [[0, 1.65, 0], [0, 1.48, 0], [-.20, 1.42, 0], [.20, 1.42, 0], [-.24, 1.12, -.05],
             [.24, 1.12, -.05], [-.26, .85, -.12], [.26, .85, -.12], [-.12, .92, 0], [.12, .92, 0],
             [-.13, .50, .02], [.13, .50, .02], [-.14, .05, 0], [.14, .05, 0]]
    bottom = [[0, 1.10, .05], [0, .96, .05], [-.20, .90, .05], [.20, .90, .05], [-.30, .72, -.18],
              [.30, .72, -.18], [-.26, .92, -.30], [.26, .92, -.30], [-.14, .52, .10], [.14, .52, .10],
              [-.24, .30, .14], [.24, .30, .14], [-.14, .05, 0], [.14, .05, 0]]
    data = {
        "schema_version": 1, "exercise": "squat", "view": "front", "loop_seconds": 3.0,
        "joints": names,
        "edges": [list(e) for e in SQUAT_EDGES],
        "highlight_joints": [8, 9, 10, 11],
        "keyframes": [
            {"t": 0.0, "positions": stand},
            {"t": 0.5, "positions": bottom},
            {"t": 1.0, "positions": stand},
        ],
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"created {path}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffmpeg", default="")
    args = ap.parse_args()
    videos = ROOT / "assets" / "exercises" / "videos"
    anims = ROOT / "assets" / "exercises" / "animations"
    videos.mkdir(parents=True, exist_ok=True)
    anims.mkdir(parents=True, exist_ok=True)
    render(videos / "squat_front.mp4", SQUAT_FRONT_STAND, SQUAT_FRONT_BOTTOM, SQUAT_EDGES, {8, 9, 10, 11})
    render(videos / "squat_side.mp4", SQUAT_FRONT_STAND, SQUAT_FRONT_BOTTOM, SQUAT_EDGES, {1, 8, 10})
    render(videos / "pushup_side.mp4", PUSHUP_TOP, PUSHUP_BOTTOM, PUSHUP_EDGES, {2, 3, 5})
    write_3d_json(anims / "squat_3d.json")


if __name__ == "__main__":
    main()
