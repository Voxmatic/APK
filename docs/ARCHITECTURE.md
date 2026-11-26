# Architecture — Offline AI Gym Trainer

## Guiding constraints

- Camera frames never cross into Dart. Native CameraX (Android) / AVFoundation (iOS) produces frames,
  MediaPipe Pose Landmarker runs in the native analyzer, and Flutter receives compact JSON events.
- All safety-critical decisions come from a deterministic engine. The optional LLM cannot override it.
- No network calls at runtime. The only internet use is the explicit desktop model downloader.

## Runtime pipeline

```
CameraX PreviewView (native platform view)
        | ImageAnalysis (STRATEGY_KEEP_ONLY_LATEST)
        v
MediaPipe PoseLandmarker LIVE_STREAM (Lite .task, CPU/GPU delegate)
        | EventChannel: {schema_version, landmarks[33], worldLandmarks[33], confidence, timestamp_ms}
        v
PoseProvider (Riverpod) --> SkeletonPainter (CustomPainter overlay)
        |
        v
ExerciseIntelligence (pure Dart, deterministic)
  joint angles / velocity / alignment / phase state machine / rep events
        |
        v
CoachEngine (policy rules + localized templates + optional LLM variation)
        |
        +--> VoiceService (bundled WAV assets, priority + cooldown)
        +--> VisualAssistance (3D ghost + local demo video)
        +--> WorkoutRepository (SQLite, AES-GCM encrypted payloads)
```

## Feature modules (`lib/features/`)

| Module | Responsibility |
|---|---|
| `camera_calibration` | Visibility/lighting checks before a workout |
| `home` | Greeting, today's plan, weekly progress, streak, start CTA |
| `exercise_library` | Search/categories, exercise metadata and demos |
| `camera_calibration` | Visibility/lighting checks; blocks workout start until landmarks ready |
| `live_workout` | Camera + skeleton + ghost + HUD + controls |
| `visual_learning` | Demo video, 3D avatar, slow motion, replay, joint highlights |
| `summary` | Reps, sets, duration, technique observations, rest advice |
| `progress` | History, weekly/monthly charts, personal records |
| `settings` | Language, voice, model management, privacy, deletion |
| `coach` | Policy engine, instruction selection, cooldown |
| `exercise_intelligence` | Biomechanics and state machines (no Flutter imports) |

## Core (`lib/core/`)

- `platform/`: typed wrappers around MethodChannel/EventChannel contracts.
- `storage/`: SQLite database + encrypted payload service.
- `models/`: versioned event schemas (`PoseFrame`, `RepCompleted`, `FormCorrection`, ...).
- `theme/`: dark/light premium fitness theme.
- `l10n/`: 13-language catalogue; English + Hindi strings shipped in first build.

## Native Android (`android/app/src/main/kotlin/...`)

- `AiTrainerPlugin`: registers camera platform view, pose event channel, secure-crypto methods.
- `CameraController`: CameraX `Preview` + `ImageAnalysis` lifecycle management.
- `PoseProcessor`: MediaPipe `PoseLandmarker` in LIVE_STREAM mode, frame dropping, JSON emission.
- `SecureCrypto`: Android Keystore AES-256/GCM key for encrypted SQLite payloads.

## Native iOS (`ios/Runner/`)

- `AiTrainerPlugin.swift`: mirror of Android contracts using AVFoundation and MediaPipeTasksVision.
- `SecureCrypto.swift`: Keychain-backed AES-GCM key.
- Source is prepared; compilation/signing requires macOS + Xcode (documented blocker).

## State management

Riverpod providers: `poseFrameProvider` (stream), `workoutControllerProvider` (Notifier),
`coachInstructionProvider`, `settingsProvider`, `workoutHistoryProvider`.
Navigation: GoRouter with guarded routes (calibration required before `/workout`).

## Event schemas

All events include `schema_version: 1` and monotonic `timestamp_ms`. See `docs/INTERNAL_APIS.md`.

## Performance strategy

- Native analyzer uses `STRATEGY_KEEP_ONLY_LATEST`; at most one in-flight pose inference.
- UI receives at most 30 compact pose events/sec; CustomPainter repaints only overlay layer.
- LLM, ASR and TTS engines are never loaded simultaneously with pose inference.
- Thermal/low-memory signals downscale the analyzer and disable the ghost avatar.
