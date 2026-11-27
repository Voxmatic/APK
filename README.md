# AI Gym Trainer

Offline Flutter app that uses the front camera and on-device MediaPipe Pose
Landmarker Lite to count squats and push-ups, correct form, coach by bundled
voice phrases, and keep workout history local. No cloud inference, cloud
speech, analytics, crash upload, or hidden telemetry.

## Status (2026-11-27)

| Area | Status |
|---|---|
| Flutter/Dart app, Riverpod state, GoRouter (19 routes) | IMPLEMENTED |
| MediaPipe Pose Landmarker Lite, verified SHA-256, CPU delegate | IMPLEMENTED on Android |
| CameraX preview + frame analysis; no frames cross to Dart | IMPLEMENTED on Android |
| Typed platform bridge, serialized camera lifecycle, permission recovery | IMPLEMENTED |
| Squat / push-up deterministic state machines | TESTED (32/32 Flutter tests) |
| Safety-first coach, cooldown, approved phrase policy | TESTED |
| Offline English/Hindi voice (54 generated WAV phrases) | IMPLEMENTED; device playback unverified |
| 3D ghost trainer (squat + push-up) and 3 local demo MP4s | IMPLEMENTED |
| Encrypted local SQLite history, export/delete | IMPLEMENTED |
| Explicit model manager with SHA-256 pinning and disk-space guard | IMPLEMENTED |
| Android debug APK | BUILT — `build/app/outputs/flutter-apk/app-debug.apk` |
| Android release APK (debug-signed) | BUILT — `build/app/outputs/flutter-apk/app-release.apk` |
| Kotlin native contract tests | 2/2 passing |
| On-device camera/pose/latency/airplane-mode verification | BLOCKED — no device or AVD attached |
| iOS native source | Source prepared; uncompiled — macOS/Xcode required |
| Trained TCN classifier / verified ASR / mobile GGUF runtime | NOT SHIPPED — documented blockers |

No accuracy percentage is claimed: there is no participant-independent
evaluation report. See `docs/TESTING.md` for exact evidence and
`docs/DEVICE_COMPATIBILITY.md` for the pending device matrix.

## Quick start

```bash
export PATH=/home/akkash/flutter/bin:/home/akkash/tools/jdk17/bin:$PATH
export ANDROID_HOME=/home/akkash/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export JAVA_HOME=/home/akkash/tools/jdk17

flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

See `docs/BUILD_INSTRUCTIONS.md` for environment setup and
`docs/ENVIRONMENT_AUDIT.md` for versions.

## Architecture (short)

- **Android native (Kotlin):** CameraX front camera → RGBA frame → MediaPipe
  Pose Landmarker Lite `LIVE_STREAM` → compact landmark map on EventChannel.
  Raw frames stay in native code.
- **Dart:** deterministic biomechanics and phase state machines decide every
  rep and form correction. The coach can only select approved messages; it
  cannot invent a count or override a stop instruction.
- **Lifecycle:** `CameraSession` serializes start/stop; native failures are
  typed data and render as retryable UI state.
- **Storage:** versioned SQLite with AES-256-GCM payload envelopes created by
  Android Keystore / iOS Keychain.
- **Voice/demos:** bundled WAV phrases, local MP4s and authored 3D keyframes;
  no runtime network path in the workout flow.

Full details: `docs/ARCHITECTURE.md`, `docs/INTERNAL_APIS.md`,
`docs/MODEL_REGISTRY.md`, `docs/DATASET_POLICY.md`, `docs/PRIVACY.md`.

## Repository layout

```
lib/                        Flutter app (features/, core/, domain/)
android/app/src/main/kotlin CameraX + MediaPipe + Keystore bridge
ios/Runner/                 prepared iOS bridge (source only on Linux)
assets/models/pose/         verified MediaPipe Lite task + manifest
assets/audio/{en,hi}/       27 offline coaching phrases per language
assets/exercises/           demo MP4s, 3D ghost JSON, metadata
ml/exercise_recognition/    research pipeline (no trained checkpoint)
scripts/                    explicit setup + asset generation
docs/                       architecture, privacy, datasets, testing, build
test/                       unit, widget, platform-contract tests
```

## Privacy

Workouts run offline. Camera frames are processed on-device and are never
uploaded or stored. No model is downloaded at app start; optional artifacts
require explicit consent and SHA-256 verification. See `docs/PRIVACY.md`.
