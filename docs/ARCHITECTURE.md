# Architecture — Offline AI Gym Trainer

## Guiding constraints

- Camera frames never cross into Dart. Native CameraX (Android) / AVFoundation
  (iOS) produces frames, MediaPipe Pose Landmarker runs in the native analyzer,
  and Flutter receives compact JSON landmark events.
- All safety-critical decisions come from deterministic biomechanics. The
  optional LLM cannot override a rep, an angle, a form error or a stop.
- No network call exists in the workout flow. The only network code is the
  explicit, consent-gated model installer.

## Runtime pipeline

```
CameraX PreviewView (native platform view)
        | ImageAnalysis (STRATEGY_KEEP_ONLY_LATEST)
        v
MediaPipe PoseLandmarker LIVE_STREAM (Lite .task, CPU delegate)
        | EventChannel ai_gym_trainer/pose: {schema_version, landmarks[33], ...}
        v
poseStreamProvider (Riverpod) --> SkeletonPainter / GhostTrainerPainter
        |
        v
WorkoutController --> SquatEngine / PushUpEngine (pure Dart, deterministic)
        |                joint angles / velocity / alignment / phase state machine
        v
CoachEngine (safety-first policy + cooldown + approved phrase ids)
        +--> VoiceService (bundled WAV assets only)
        +--> Visual learning (authored 3D ghost + local demo MP4)
        +--> WorkoutStore (SQLite + AES-256-GCM encrypted payload envelope)
```

## Feature modules (`lib/features/`)

| Module | Responsibility |
|---|---|
| `onboarding`, `permissions`, `compatibility` | First-run explanation, real permission recovery, device/model readiness |
| `camera_calibration` | Full-body visibility gate before a workout |
| `home`, `plans`, `exercise_library`, `progress`, `summary` | Navigation, local plans, metadata, history, results |
| `live_workout` | Awaited camera start, skeleton/ghost overlay, HUD, rest/finish/safety |
| `workout` | `WorkoutController` state machine and rest screen |
| `exercise_intelligence` | Biomechanics, deterministic squat/push-up engines, versioned events |
| `coach` | Policy engine, priority, cooldown, visual demo mapping |
| `voice` | Offline WAV playback, language switching, voice self-test screen |
| `visual_learning` | Asset-driven 3D ghost interpolation and skeleton painter |
| `models`, `local_ai`, `diagnostics`, `privacy`, `help`, `settings` | Model manager, honest feature status, native diagnostics, data controls |

## Core (`lib/core/`)

- `platform/pose_channel.dart`: typed bridge; every native failure is data.
- `platform/camera_session.dart`: serialized start/stop ownership queue.
- `settings/app_settings.dart`: persisted language, voice, visualization,
  onboarding, plan and explicit model-install consent.
- `storage/workout_db.dart`: SQLite store and `PayloadCipher` boundary.
- `models/`: manifest parsing, SHA-256 verification, explicit installer.
- `l10n/strings.dart`: 13-language catalogue; full en/hi translations.
- `theme/`: dark fitness theme.

## Native Android (`android/app/src/main/kotlin/...`)

- `AiTrainerPlugin`: channels, platform view, permission, lifecycle, diagnostics,
  storage encryption, model registration.
- `CameraController`: CameraX preview/analysis lifecycle; deferred attach; typed errors.
- `PoseProcessor`: MediaPipe `LIVE_STREAM`, bundled-model checksum verification,
  compact map emission.
- `SecureCrypto`: Android Keystore AES-256-GCM.
- `NativeContract`: pure constants shared with JVM unit tests.

## Native iOS (`ios/Runner/`)

- `AiTrainerPlugin.swift`: AVFoundation + MediaPipe mirror of the Android
  contract, with preview layer attached to the platform view and a separate
  system-event stream handler. Source prepared; uncompiled on Linux.

## State and navigation

Riverpod: `poseStreamProvider`, `systemEventsProvider`,
`workoutControllerProvider`, `settingsControllerProvider`, `voiceServiceProvider`,
`cameraSessionProvider`, `modelManagerProvider`, `ghostClipProvider`.
GoRouter: 19 routes, onboarding redirect, shell navigation for the four main
tabs, immersive full-screen routes for camera/demo/settings sub-pages.

## Event schemas

All native events include `schema_version: 1`; rep and form events are
versioned and covered by `test/integration/platform_contract_test.dart`.
See `docs/INTERNAL_APIS.md`.
