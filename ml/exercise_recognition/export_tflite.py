"""Export the trained PyTorch TCN to TFLite via ONNX.

Requires: torch, onnx, onnx2tf / tensorflow. Run only after training.
The exported file goes to assets/models/exercise/ and is registered in the manifest.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import torch

from model import ExerciseTCN
from preprocessing import FEATURES


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--out", type=Path, default=Path("assets/models/exercise/exercise_tcn_v1.onnx"))
    args = ap.parse_args()
    ckpt = torch.load(args.checkpoint, map_location="cpu", weights_only=False)
    model = ExerciseTCN(input_features=FEATURES)
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    dummy = torch.zeros(1, 64, FEATURES)
    torch.onnx.export(
        model, dummy, str(args.out),
        input_names=["pose_sequence"],
        output_names=["exercise", "phase", "error"],
        dynamic_axes={"pose_sequence": {0: "batch"}},
        opset_version=17,
    )
    print(f"Exported ONNX to {args.out}; convert to TFLite with onnx2tf before Android integration.")


if __name__ == "__main__":
    main()
