"""Train the TCN. Requires PyTorch and a licensed, labelled dataset.

Usage: python3 ml/exercise_recognition/train.py --data data/ --epochs 30
Dataset policy: docs/DATASET_POLICY.md. Never train on a dataset whose licence
prohibits your intended (including commercial) use.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset

from model import ExerciseTCN
from preprocessing import FEATURES, load_sample, landmark_matrix, participant_split, to_tensor


class PoseDataset(Dataset):
    def __init__(self, files: list[Path]):
        self.samples = []
        for path in files:
            data = load_sample(path)
            features = to_tensor(landmark_matrix(data["frames"]))
            if features.shape != (64, FEATURES):
                continue
            self.samples.append((
                features,
                ExerciseTCN.EXERCISES.index(data["exercise"]),
                ExerciseTCN.PHASES.index(data["phase"]),
                ExerciseTCN.ERRORS.index(data.get("error", "none")),
            ))

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, i: int):
        x, e, p, err = self.samples[i]
        return torch.from_numpy(x), e, p, err


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--out", type=Path, default=Path("ml/exercise_recognition/checkpoints/tcn_v1.pt"))
    args = ap.parse_args()

    files = sorted(args.data.glob("*.json"))
    if len(files) < 20:
        raise SystemExit("Need at least 20 labelled samples before training.")
    train_files, val_files = participant_split(files)
    train_loader = DataLoader(PoseDataset(train_files), batch_size=args.batch, shuffle=True)
    val_loader = DataLoader(PoseDataset(val_files), batch_size=args.batch)
    model = ExerciseTCN(input_features=FEATURES)
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
    criterion = nn.CrossEntropyLoss()
    best = float("inf")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    for epoch in range(args.epochs):
        model.train()
        total = 0.0
        for x, e, p, err in train_loader:
            optimizer.zero_grad()
            out = model(x)
            loss = (
                criterion(out["exercise"], e)
                + 0.5 * criterion(out["phase"], p)
                + 0.25 * criterion(out["error"], err)
            )
            loss.backward()
            optimizer.step()
            total += float(loss)
        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for x, e, p, err in val_loader:
                out = model(x)
                val_loss += float(
                    criterion(out["exercise"], e)
                    + 0.5 * criterion(out["phase"], p)
                    + 0.25 * criterion(out["error"], err)
                )
        print(f"epoch {epoch + 1:02d} train={total / max(1, len(train_loader)):.4f} val={val_loss / max(1, len(val_loader)):.4f}")
        if val_loss < best:
            best = val_loss
            torch.save({"state_dict": model.state_dict(), "schema": 1, "epoch": epoch + 1}, args.out)
    print(f"Saved best checkpoint to {args.out} (val_loss={best:.4f})")


if __name__ == "__main__":
    main()
