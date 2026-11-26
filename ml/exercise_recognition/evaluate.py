"""Held-out participant-independent evaluation of a trained TCN checkpoint."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import classification_report  # optional dependency

from model import ExerciseTCN
from preprocessing import FEATURES, load_sample, landmark_matrix, participant_split, to_tensor


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--checkpoint", type=Path, required=True)
    args = ap.parse_args()

    files = sorted(args.data.glob("*.json"))
    _, val_files = participant_split(files)
    ckpt = torch.load(args.checkpoint, map_location="cpu", weights_only=False)
    model = ExerciseTCN(input_features=FEATURES)
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    truth: dict[str, list[int]] = {"exercise": [], "phase": [], "error": []}
    preds: dict[str, list[int]] = {"exercise": [], "phase": [], "error": []}
    with torch.no_grad():
        for path in val_files:
            data = load_sample(path)
            x = torch.from_numpy(to_tensor(landmark_matrix(data["frames"]))).unsqueeze(0)
            out = model(x)
            targets = {
                "exercise": ExerciseTCN.EXERCISES.index(data["exercise"]),
                "phase": ExerciseTCN.PHASES.index(data["phase"]),
                "error": ExerciseTCN.ERRORS.index(data.get("error", "none")),
            }
            for key in truth:
                truth[key].append(targets[key])
                preds[key].append(int(out[key].argmax(1).item()))
    report = {}
    for key in truth:
        report[key] = classification_report(
            truth[key], preds[key], labels=range(len(getattr(ExerciseTCN, key.upper()))),
            output_dict=True, zero_division=0,
        )
    print(json.dumps(report, indent=2))
    Path("ml/exercise_recognition/evaluation_report.json").write_text(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
