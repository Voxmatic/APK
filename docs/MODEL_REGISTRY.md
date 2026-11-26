# Model Registry — Offline AI Gym Trainer

Last audit: 2026-11-26. All entries are based on official sources checked on that date.
Model binaries are **not committed to Git**. They are downloaded explicitly with
`python3 scripts/download_models.py --group <group>` and verified against this registry.

## Status definitions

`NOT_STARTED` · `IN_PROGRESS` · `IMPLEMENTED` · `TESTED` · `VERIFIED_ON_DEVICE` · `BLOCKED`

---

## 1. Body tracking — MediaPipe Pose Landmarker Lite (primary)

| Field | Value |
|---|---|
| Model name | Pose Landmarker Lite (`pose_landmarker_lite.task`) |
| Official source | https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker |
| Direct source | `https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task` |
| Repository | https://github.com/google-ai-edge/mediapipe |
| Model version | `float16/1` (Google-hosted bundle; version path is part of the URL) |
| Parameter count | Not published in the task bundle (BlazePose-based pose detector + landmark model) |
| Original model size | 5,777,746 bytes (as served by Google) |
| Downloaded file size | 5,777,746 bytes (5.51 MiB) |
| Quantization | float16 |
| Format | MediaPipe `.task` bundle (TFLite models + graph) |
| Licence | Apache-2.0 (MediaPipe model card / repository licence) |
| Intended use | 33 full-body landmarks, world landmarks, visibility/presence, real-time on mobile |
| Runtime | MediaPipe Tasks Vision (Android Kotlin `com.google.mediapipe:tasks-vision`, iOS `MediaPipeTasksVision`) |
| Hardware requirements | Android API 24+, CPU (GPU delegate attempted with CPU fallback) |
| Conversion status | No conversion needed; official mobile bundle |
| Actual device test status | NOT_STARTED (no physical device or emulator attached in this environment) |
| SHA-256 | `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a` |

**Notes**

- Running mode `LIVE_STREAM` is used: MediaPipe drops frames internally when busy, so the same
  camera frame is never processed twice and callbacks remain current.
- Lite is used first. Full model is a documented fallback only if Lite accuracy is insufficient.
- Output: 33 normalized landmarks `(x, y, z, visibility, presence)` plus 33 world landmarks when available.

## 2. Body tracking fallback — MediaPipe Pose Landmarker Full

| Field | Value |
|---|---|
| Official source | https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task |
| Version | `float16/1` |
| Format | MediaPipe `.task` |
| Licence | Apache-2.0 |
| Original size | 9,398,198 bytes (9.0 MiB) |
| Status | NOT_DOWNLOADED — only download if Lite fails accuracy validation |
| SHA-256 | Recorded by `scripts/download_models.py` when downloaded |

## 3. Exercise recognition — custom Temporal Convolutional Network

| Field | Value |
|---|---|
| Model name | `aitrainer_tcn_v1` (project-owned) |
| Official source | `ml/exercise_recognition/` in this repository |
| Version | `0.1.0` (architecture + training pipeline only) |
| Parameters | ~180k (configurable, see `model.py`) |
| Input schema | `[batch, 64, 132]`: 33×3 pose coords + 33 visibility + 33 derived joint angles/features = 132 |
| Outputs | exercise class (6), movement phase (4), technique error (6) |
| Format | TFLite (planned export), `.pt` training checkpoint |
| Licence | Project source licence; training data licences govern trained weights — see `docs/DATASET_POLICY.md` |
| Status | NOT_TRAINED — no checkpoint exists. The shipped runtime uses the deterministic biomechanics engine instead. |
| Device test status | NOT_STARTED |

**Do not treat this as a trained model.** `scripts/verify_models.py` will report it as missing until a
properly labelled dataset is recorded and training is run.

## 4. Conversational intelligence — Qwen3.5-0.8B (OPTIONAL, not loaded during workouts)

| Field | Value |
|---|---|
| Model name | `Qwen3.5-0.8B-Q4_0.gguf` |
| Official source | https://huggingface.co/Qwen/Qwen3.5-0.8B |
| Quantized source | https://huggingface.co/ggml-org/Qwen3.5-0.8B-GGUF |
| Version | Qwen3.5-0.8B post-trained, 2026-02 release |
| Parameters | 0.8B |
| Original model size | 1,557,660,640 bytes (BF16 GGUF) |
| Downloaded file size | 563,036,064 bytes (537 MiB) if installed |
| Quantization | Q4_0 (4-bit); Q8_0 and BF16 also published |
| Format | GGUF (`qwen35` architecture, hybrid Gated DeltaNet + attention + vision tower) |
| Licence | Apache-2.0 (official and ggml-org repos) |
| Intended use | Optional policy-constrained natural-language coaching/explanations only |
| Runtime | llama.cpp-compatible local inference. **Not bundled or auto-loaded.** |
| Hardware requirements | ~600 MB weights + KV cache; likely below 8 GB phones but unvalidated here |
| Conversion status | Official GGUF conversion by ggml-org |
| Actual device test status | BLOCKED for this milestone — no Android device/emulator; not enabled in normal workout path |
| SHA-256 | Compute on download via `download_models.py --group llm` and record here |

**Genuine technical finding:** Qwen3.5-0.8B is a *multimodal hybrid* architecture (`qwen35`), not a
simple transformer. Mobile llama.cpp support for this new architecture must be validated on-device
before it can be enabled. Default coaching remains rule-based/localized templates; the LLM is never
used for reps, angles, safety, or exercise decisions.

## 5. Speech recognition — AI4Bharat IndicConformer (OPTIONAL candidate)

| Field | Value |
|---|---|
| Official source | https://github.com/AI4Bharat/IndicConformerASR |
| Licence | MIT (repository LICENSE) |
| Variants | Multilingual 600M + 23 monolingual checkpoints (as, bn, brx, doi, gu, hi, kn, kok, ks, mai, ml, mni, mr, ne, or, pa, sa, sat, sd, ta, te, ur) |
| Format | NeMo `.nemo` — ONNX export required for mobile |
| Runtime candidate | sherpa-onnx (https://github.com/k2-fsa/sherpa-onnx) |
| Status | NOT_DOWNLOADED — 600M multilingual bundle is deliberately excluded from the default package |
| Device test status | NOT_STARTED |
| Decision | Optional voice commands; every command has an on-screen equivalent. Not part of first working release. |

## 6. Offline TTS — pre-generated coaching phrases (default)

| Field | Value |
|---|---|
| Runtime | Bundled WAV assets played by `audioplayers` (Android MediaPlayer / iOS AVAudioPlayer) |
| Generation | Build-time generation script; playback needs no network and no TTS engine |
| Languages in first build | `en`, `hi` |
| Voices | Generated with eSpeak NG when available; see `scripts/generate_voice_assets.py` |
| Licence | eSpeak NG GPL-3.0 (generated audio assets are data; distribution review required before commercial release) |
| Status | IMPLEMENTED (assets generated locally) |
| Device test status | NOT_STARTED |

## 7. Offline TTS alternatives investigated

| Model | Source | Licence | Finding |
|---|---|---|---|
| Piper | https://github.com/OHF-Voice/piper1-gpl | GPL-3.0 | Real offline neural TTS, but GPL-3.0 has distribution obligations. Voice/model licences must be checked per voice. |
| IndicF5 | https://huggingface.co/Aditya02/IndicF5 | Check model card before use | Not suitable as the first mobile runtime; benchmark required. NOT bundled. |
| sherpa-onnx TTS | https://github.com/k2-fsa/sherpa-onnx | Apache-2.0 | Viable future runtime for language packs; not enabled in first build. |

## Download-size plan

| Group | Contents | Approx. size |
|---|---|---:|
| `pose` | MediaPipe Lite task | 5.7 MB |
| `pose-full` | MediaPipe Full task (optional) | 9.4 MB |
| `exercise` | TCN weights (not yet trained) | 0 MB |
| `llm` | Qwen3.5-0.8B-Q4_0.gguf | 563 MB |
| `speech` | IndicConformer (not bundled by default) | TBD after ONNX conversion |
| `voice` | Piper / sherpa-onnx voice packs (optional) | TBD |

`--group all` downloads the approved available set (pose + llm ≈ 569 MB) only after showing the total
and requiring explicit confirmation. No multi-gigabyte model is downloaded silently.
