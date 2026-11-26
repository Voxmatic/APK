"""Temporal Convolutional Network for exercise recognition from pose sequences.

Input schema (v1): [batch, 64, 132]
  0..32   landmark x (normalized, hip-centred)
  33..65  landmark y
  66..98  landmark z (relative depth)
  99..131 visibility/confidence

Outputs: exercise logits (6), phase logits (4), technique-error logits (6).
NOTE: no checkpoint is shipped. This model must be trained on licensed, labelled data.
"""
from __future__ import annotations

import torch
from torch import nn


class TemporalBlock(nn.Module):
    def __init__(self, in_ch: int, out_ch: int, kernel: int, dilation: int, dropout: float = 0.1):
        super().__init__()
        pad = (kernel - 1) * dilation
        self.net = nn.Sequential(
            nn.Conv1d(in_ch, out_ch, kernel, padding=pad, dilation=dilation),
            nn.Chomp1d(pad) if hasattr(nn, "Chomp1d") else nn.Identity(),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Conv1d(out_ch, out_ch, kernel, padding=pad, dilation=dilation),
            nn.Chomp1d(pad) if hasattr(nn, "Chomp1d") else nn.Identity(),
            nn.ReLU(),
            nn.Dropout(dropout),
        )
        self.downsample = nn.Conv1d(in_ch, out_ch, 1) if in_ch != out_ch else nn.Identity()
        self.relu = nn.ReLU()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.relu(self.net(x) + self.downsample(x))


class Chomp1d(nn.Module):
    """Remove right padding so the output length equals the input length."""

    def __init__(self, chomp: int):
        super().__init__()
        self.chomp = chomp

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x[:, :, :-self.chomp].contiguous() if self.chomp > 0 else x


class TemporalAttention(nn.Module):
    def __init__(self, channels: int):
        super().__init__()
        self.score = nn.Sequential(nn.Linear(channels, channels // 2), nn.Tanh(), nn.Linear(channels // 2, 1))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: [B, T, C]
        weights = torch.softmax(self.score(x), dim=1)
        return (x * weights).sum(dim=1)


class ExerciseTCN(nn.Module):
    EXERCISES = ["squat", "pushup", "bicep_curl", "lunge", "shoulder_press", "plank"]
    PHASES = ["ready", "descent", "bottom", "ascent"]
    ERRORS = [
        "none", "knees_collapsing_inward", "hip_sag", "insufficient_depth",
        "trunk_lean", "low_visibility",
    ]

    def __init__(self, input_features: int = 132, hidden: int = 96, dropout: float = 0.1):
        super().__init__()
        self.input_proj = nn.Conv1d(input_features, hidden, 1)
        self.blocks = nn.Sequential(
            TemporalBlock(hidden, hidden, 3, 1, dropout),
            TemporalBlock(hidden, hidden, 3, 2, dropout),
            TemporalBlock(hidden, hidden, 3, 4, dropout),
        )
        self.attention = TemporalAttention(hidden)
        self.exercise_head = nn.Linear(hidden, len(self.EXERCISES))
        self.phase_head = nn.Linear(hidden, len(self.PHASES))
        self.error_head = nn.Linear(hidden, len(self.ERRORS))

    def forward(self, x: torch.Tensor) -> dict[str, torch.Tensor]:
        # x: [B, T, F] -> [B, F, T]
        h = self.input_proj(x.transpose(1, 2))
        h = self.blocks(h).transpose(1, 2)
        pooled = self.attention(h)
        return {
            "exercise": self.exercise_head(pooled),
            "phase": self.phase_head(pooled),
            "error": self.error_head(pooled),
        }


if __name__ == "__main__":
    model = ExerciseTCN()
    sample = torch.randn(2, 64, 132)
    out = model(sample)
    print({k: tuple(v.shape) for k, v in out.items()})
