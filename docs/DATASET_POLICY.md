# Dataset and Training Policy

## Rule

No model is trained on a dataset until its licence is checked for the intended use (including
commercial use). Research-only / non-commercial datasets must not be used for a commercial model.

| Dataset | Reference | Licence check | Use here |
|---|---|---|---|
| Fit3D | https://fit3d.imar.ro/ | Must request/verify terms | NOT downloaded / NOT used |
| FLAG3D | https://andytang15.github.io/FLAG3D/ | Must verify research-only terms | NOT downloaded / NOT used |
| RepCount | https://svip-lab.github.io/dataset/RepCount_dataset | Must verify terms | NOT downloaded / NOT used |
| QEVD | https://www.qualcomm.com/developer/software/qevd-dataset | Must verify terms | NOT downloaded / NOT used |
| Own recordings | Recorded by user with consent | Project-owned | Preferred source |

## Annotation schema

Each sample is one JSON file named `<participant_id>_<session>_<index>.json`:

```json
{
  "schema_version": 1,
  "participant": "p001",
  "exercise": "squat",
  "phase": "descent",
  "error": "none",
  "camera_view": "front",
  "frames": [
    {"t_ms": 0, "landmarks": [{"x": 0.5, "y": 0.4, "z": 0.0, "visibility": 0.9}]}
  ]
}
```

Exactly 33 landmarks per frame. Coordinates are normalized image coordinates.

## Splitting and validation

- `participant_split()` in `ml/exercise_recognition/preprocessing.py` groups by participant id,
  so no participant appears in both train and validation.
- Report precision/recall per class, rep-count MAE, false-positive correction rate, and confidence
  calibration on held-out participants.
- Accuracy claims require this report; no accuracy number is claimed in this repository yet.

## Reproducibility

Record dataset version, participant count, frame count, preprocessing schema version, seed,
checkpoint hash, and evaluation report alongside every trained model.
