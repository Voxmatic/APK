# Execution log

Ordered, evidence-based log. Every entry records what was executed, not intent.

## 2026-11-27 — M0 Audit

- Inspected the full repository (`lib/`, `android/`, `ios/`, `assets/`, `ml/`,
  `scripts/`, `test/`, `docs/`).
- Toolchain: Flutter 3.50.1 / Dart 3.14.0, Temurin JDK 17, Gradle 9.5.0,
  AGP 9.3.1, Kotlin 2.4.20, native Linux Android SDK 36. `adb devices -l`:
  no devices, no AVDs. No macOS/Xcode.
- Baseline `flutter analyze`: 19 info / 0 errors. Baseline `flutter test`: 20/20.
- Verified bundled pose model SHA-256
  `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`
  against `assets/models/manifest.json`.
- Created `INITIAL_AUDIT.md`, `CRASH_ROOT_CAUSE.md`, and this log.
- Added a temporary crash repro, later replaced by permanent lifecycle tests.

## 2026-11-27 — M1 Stability

- Added direct deps `http`, `crypto`, `video_player`; added manifest to assets.
- Replaced unsafe MethodChannel usage with `PlatformResult` typed bridge in
  `lib/core/platform/pose_channel.dart`; all native exceptions become data.
- Added `CameraSession` queue so late `stop()` cannot race a new `start()`.
- Rewrote Android `AiTrainerPlugin.kt`, `CameraController.kt`,
  `PoseProcessor.kt`, `MainActivity.kt`: per-view preview, deferred attach,
  permission/lifecycle events, checksum verification, typed errors.
- Rewrote `WorkoutController` around awaited `beginCamera()`, real frames,
  permission states, rest/finish and pain-stop rules.
- Added encrypted persistence (`WorkoutStore`, `PayloadCipher`,
  `NativePayloadCipher`, `MemoryWorkoutStore`) and persisted `AppSettings`.
- Updated every screen to remove the original fire-and-forget `camera.start`
  crash path; provider writes are deferred to post-frame callbacks.
- Regenerated 54 WAV phrases (27 en + 27 hi) and verified asset indexes.
- Removed `crash_repro_test.dart`; added `test/widget/camera_lifecycle_test.dart`
  covering native start failure, successful start and pending permission.
- Evidence: `flutter analyze` 0 errors/0 warnings; `flutter test` 32/32.

## 2026-11-27 — M2 Real camera / M3 Real pose AI

- Android CameraX front camera with `STRATEGY_KEEP_ONLY_LATEST`, rotation-aware
  RGBA conversion, per-view `PreviewView`, and attach-gated start.
- MediaPipe Tasks Vision 1.2.3 `PoseLandmarker` in `LIVE_STREAM` mode with the
  bundled verified Lite task, CPU delegate, 33 landmarks + world landmarks,
  visibility/presence and inference timing.
- No raw frame crosses into Dart. Native pose events are compact versioned maps.
- Fixed Kotlin compile error `Image.Plane` → `ImageProxy.PlaneProxy`.
- Evidence: `flutter build apk --debug` and `--release` both succeed;
  `aapt dump badging` confirms package, API 26 min / 36 target, camera permission.

## 2026-11-27 — M4 Exercise intelligence / M5 Offline coaching

- Deterministic squat and push-up phase engines; reps only after full phase
  sequences. Pain, visibility, alignment and tempo rules are on-screen and
  voice-approved; no model can override them.
- Added local `WorkoutPlan` catalog, between-set rest, summary and progress.
- Offline voice plays only bundled WAV assets; voice service creates its audio
  player lazily and reports missing assets as state rather than exceptions.
- Added English/Hindi keys for every dynamic phrase and a test that all UI keys
  used in `lib/` resolve in both languages.

## 2026-11-27 — M6 Optional local AI / M7 Speech

- Added explicit model manager: manifest-driven HTTPS downloads, free-space
  check, size check, SHA-256 pinning/verification, consent toggle, removal.
- Added honest Local AI and Voice screens: deterministic coaching remains
  authoritative; no verified mobile GGUF runtime or offline ASR is advertised.
- No optional model is downloaded or loaded at app start.

## 2026-11-27 — M8 Visual trainer / M9 Complete app

- Authored push-up 3D ghost clip; squat clip already present. Ghost painter
  interpolates keyframes and projects depth with a yaw.
- Added local demo video playback with pause, 3D ghost toggle and slow motion.
- Wired 19 routes including onboarding, permissions, compatibility, plans,
  model manager, voice, local AI, diagnostics, privacy, help, rest and demo.
- `main.dart` preloads persisted settings; app-level lifecycle observer feeds
  the camera/workout controller.
- iOS plugin source now attaches its preview layer to the platform view and
  uses a separate system-event stream handler. iOS remains uncompiled (no macOS).

## 2026-11-27 — M10 Final validation

- `dart format lib test`: clean.
- `flutter analyze`: 0 errors, 0 warnings (informational lints only).
- `flutter test --timeout 60s`: 32/32 passing.
- `cd android && ./gradlew :app:testDebugUnitTest`: 2/2 Kotlin contract tests
  passing. Full Gradle `test` fails only in upstream
  `shared_preferences_android` Robolectric SDK 36, which requires Java 21;
  documented blocker, not hidden.
- `flutter build apk --debug`: `app-debug.apk` 249 MB, valid APK per `file` and
  `aapt dump badging`.
- `flutter build apk --release`: `app-release.apk` 115.8 MB, valid APK,
  debug-signed for local validation.
- Final post-localization rebuild repeated both APKs successfully; pose model
  SHA-256 rechecked as
  `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`.
- Updated README and all docs with measured results and explicit blockers.
- Device verification remains BLOCKED: no Android device/AVD, no macOS/Xcode,
  no verified ASR bundle, no trained TCN checkpoint, no validated mobile
  `qwen35` GGUF runtime.
