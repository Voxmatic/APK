# AI Gym Trainer

Fully offline Flutter app that tracks your body with the front camera, recognizes
squats and push-ups, counts reps, gives form feedback, and coaches you by voice —
without cloud inference, cloud vision, cloud speech, analytics or telemetry.

## Status (2026-11-26)

| Area | Status |
|---|---|
| Flutter/Dart scaffold + Riverpod + GoRouter | IMPLEMENTED |
| MediaPipe Pose Landmarker Lite (33 landmarks, on-device) | IMPLEMENTED (native Android done) |
| CameraX live preview + frame analysis (no frames cross to Dart) | IMPLEMENTED (Android) |
| Squat / push-up state machines, deterministic rep counting | TESTED (20/20 unit + contract tests) |
| Offline English/Hindi voice (46 eSpeak NG WAV phrases) | IMPLEMENTED (device playback BLOCKED) |
| 3D ghost trainer + local demo MP4s | IMPLEMENTED |
| Local SQLite workout history | IMPLEMENTED |
| Android debug APK | BUILT — `build/app/outputs/flutter-apk/app-debug.apk` (219 MB) |
| On-device camera/pose verification | BLOCKED — no Android device or AVD attached |
| iOS native source | IN_PROGRESS — prepared, cannot compile on Linux |
| Trained exercise classifier | NOT_STARTED — Python ML deps unavailable |

No accuracy percentage is claimed: there is no participant-independent evaluation
report yet. See `docs/TESTING.md` for exact test evidence and `docs/DEVICE_COMPATIBILITY.md`
for the pending on-device matrix.

## Quick start

```bash
export PATH=/home/akkash/flutter/bin:$PATH
export JAVA_HOME=/home/akkash/tools/jdk17
export PATH=$JAVA_HOME/bin:$PATH
export ANDROID_HOME=/home/akkash/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

See `docs/BUILD_INSTRUCTIONS.md` for the full environment setup (including how
the Linux Android SDK was installed) and `docs/ENVIRONMENT_AUDIT.md` for versions.

## Architecture (short)

- **Android native (Kotlin):** CameraX front camera → RGBA frame → MediaPipe
  Pose Landmarker Lite `LIVE_STREAM` → compact landmark map on EventChannel
  `ai_gym_trainer/pose`. Raw camera frames never leave native code.
- **Dart:** pure deterministic biomechanics/state-machine engine decides reps and
  form errors. A rule-based coach applies safety first; an optional LLM could
  only add motivation and can never override a count or a stop instruction.
- **Storage:** SQLite (`sqflite`) with versioned event schemas; payloads encrypted
  with an Android Keystore-backed AES-256-GCM key before write (bridge ready).
- **Voice/demos:** bundled WAV phrases and MP4/JSON animations — no runtime network.

Full details: `docs/ARCHITECTURE.md`, `docs/INTERNAL_APIS.md`, `docs/MODEL_REGISTRY.md`,
`docs/DATASET_POLICY.md`, `docs/PRIVACY.md`.

## Repository layout

```
lib/                     Flutter app (features/, core/)
android/app/src/main/kotlin/  CameraX + MediaPipe + Keystore bridge
ios/Runner/              prepared iOS bridge (source only on Linux)
assets/models/pose/      verified MediaPipe Lite task + manifest
assets/audio/{en,hi}/    generated offline coaching phrases
assets/exercises/        demo MP4s, 3D ghost JSON, metadata
ml/exercise_recognition/ research pipeline (train/evaluate/export)
scripts/                 explicit setup + asset generation + benchmarks
docs/                    architecture, privacy, datasets, testing, build, devices
test/                    unit + platform-contract tests
```

## Privacy

Workouts run offline. Camera frames are processed on-device and are never
uploaded, stored, or sent to any service. See `docs/PRIVACY.md`.
# APK
