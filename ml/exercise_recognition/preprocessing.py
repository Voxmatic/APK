"""Pose-sequence preprocessing shared by training and evaluation.

Schema version 1: 64 frames x 132 features.
Frame features: x[33], y[33], z[33], visibility[33].
Derived angles are appended by the runtime engine but kept out of v1 so the
same code can be used for raw MediaPipe landmark sequences.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

SEQ_LEN = 64
NUM_LANDMARKS = 33
FEATURES = NUM_LANDMARKS * 4

LEFT_HIP, RIGHT_HIP, LEFT_SHOULDER, RIGHT_SHOULDER = 23, 24, 11, 12


def load_sample(path: Path) -> dict:
    """Load a labelled JSON sample: {exercise, phase, error, frames:[{landmarks:[{x,y,z,visibility}]}]}."""
    data = json.loads(path.read_text(encoding="utf-8"))
    frames = data["frames"]
    if not frames:
        raise ValueError(f"empty sample: {path}")
    return data


def landmark_matrix(frames: list[dict]) -> np.ndarray:
    """Return [T, 33, 4] with hip-centred x/y/z and visibility."""
    raw = np.zeros((len(frames), NUM_LANDMARKS, 4), dtype=np.float32)
    for t, frame in enumerate(frames):
        lms = frame["landmarks"]
        if len(lms) != NUM_LANDMARKS:
            raise ValueError(f"expected 33 landmarks, got {len(lms)} at frame {t}")
        for i, lm in enumerate(lms):
            raw[t, i] = [lm["x"], lm["y"], lm["z"], lm.get("visibility", 0.0)]
    centre = (raw[:, LEFT_HIP] + raw[:, RIGHT_HIP]) / 2
    raw[:, :, :3] -= centre[:, None, :3]
    return raw


def resample(raw: np.ndarray, length: int = SEQ_LEN) -> np.ndarray:
    t = raw.shape[0]
    if t == 0:
        raise ValueError("empty sequence")
    idx = np.linspace(0, t - 1, length).round().astype(int)
    return raw[idx]


def to_tensor(raw: np.ndarray) -> np.ndarray:
    """[T, 33, 4] -> [T, 132]."""
    return resample(raw).reshape(length_features()).astype(np.float32)


def length_features() -> tuple[int, int]:
    return SEQ_LEN, FEATURES


def participant_split(files: list[Path], val_fraction: float = 0.2, seed: int = 42):
    """Group by participant id embedded in filename `<participant>_<rest>.json`."""
    rng = np.random.default_rng(seed)
    groups: dict[str, list[Path]] = {}
    for path in files:
        key = path.stem.split("_")[0]
        groups.setdefault(key, []).append(path)
    keys = sorted(groups)
    rng.shuffle(keys)
    val_count = max(1, int(len(keys) * val_fraction))
    val_keys = set(keys[:val_count])
    train = [p for k in keys if k not in val_keys for p in groups[k]]
    val = [p for k in keys if k in val_keys for p in groups[k]]
    return train, val
