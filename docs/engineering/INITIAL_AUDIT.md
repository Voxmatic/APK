# M0 — Initial engineering audit

Audit date: 2026-11-27. Workspace: `/mnt/c/Users/91832/Pictures/Mtrain`.
Nothing was deleted or regenerated before this audit. The repository already contains a
substantial Flutter/Kotlin/iOS implementation, so the work from here is **repair + completion**.

## 1. Versions and toolchain (measured)

| Item | Measured value | Evidence |
|---|---|---|
| Flutter | 3.50.1 stable, framework `ae9b586f34`, engine `51379e6df4` | `flutter --version` |
| Dart | 3.14.0 | same |
| Flutter SDK path | `/home/akkash/flutter` (stale Windows PATH entry `/mnt/c/flutter/src/flutter/bin` is not a SDK) | `which flutter` / `env` |
| Java | Temurin JDK 17 at `/home/akkash/tools/jdk17` (`/usr/bin/java` is a JRE without `javac`) | `javac` presence |
| Gradle wrapper | 9.5.0 (`gradle-9.5.0-all.zip`) | `android/gradle/wrapper/gradle-wrapper.properties` |
| AGP / Kotlin plugin | AGP 9.3.1, Kotlin 2.4.20 | `android/settings.gradle.kts` |
| Android SDK | Native Linux SDK `/home/akkash/android-sdk`, platform 36, build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1 | SDK directory listing |
| CameraX | 1.5.3 | `android/app/build.gradle.kts` |
| MediaPipe Tasks Vision | 1.2.3 (Android); iOS source imports `MediaPipeTasksVision` without a pinned SPM/Pod version | Gradle / `ios/Runner/AiTrainerPlugin.swift` |
| Dart dependencies | Riverpod 3.5, GoRouter 18.1, audioplayers 6.8, path_provider 2.1, shared_preferences 2.5, sqflite 2.4, flutter_lints 6 | `pubspec.yaml` / `pubspec.lock` |
| ADB devices | **none** | `adb devices -l` |
| AVDs | **none** | `emulator -list-avds` (empty) |
| Host CPU/RAM | i5-8250U, 8 vCPU exposed; WSL 3.8 GiB RAM + 8 GiB swap | `free -h` |
| Free disk | WSL ext4 928 GiB; Windows C: only 6.8 GiB | `df -h` |

## 2. Architecture as found

- `lib/main.dart` → `AiGymTrainerApp` (GoRouter `ShellRoute` + 7 screens).
- Native Android: `AiTrainerPlugin.kt` registers `MethodChannel ai_gym_trainer/camera`,
  `EventChannel ai_gym_trainer/pose`, and platform view `ai_gym_trainer/camera_view`.
  `CameraController.kt` uses CameraX `Preview` + `ImageAnalysis` (RGBA_8888, KEEP_ONLY_LATEST)
  on a single-thread executor. `PoseProcessor.kt` runs MediaPipe Pose Landmarker Lite in
  `LIVE_STREAM` mode and emits compact landmark maps. `SecureCrypto.kt` wraps Android Keystore
  AES-256-GCM, but **Dart never calls it for workout history**.
- iOS: `ios/Runner/AiTrainerPlugin.swift`, `SecureCrypto.swift`, `SceneDelegate` and project
  files exist. The Swift preview factory never attaches `previewLayer` to its `UIView`, so even
  on macOS the camera preview would be blank. Not compilable on Linux.
- Domain: pure-Dart biomechanics + deterministic squat/push-up state machines + rule-based coach.
- Assets: verified MediaPipe Lite task, 46 en/hi WAV phrases, 3 procedural MP4 demos,
  one 3D joint-keyframe JSON, exercise metadata.
- ML: `ml/exercise_recognition/` has a TCN source pipeline but **no checkpoint, no dataset and
  no evaluation report**. It is not integrated into the app.

## 3. Build/test baseline actually executed

| Check | Result |
|---|---|
| `flutter pub get` | Dependencies already resolved; `pubspec.lock` consistent. |
| `flutter analyze` | 19 info-level issues, **0 errors** (deprecated `material.dart`, `withOpacity`, async context). |
| `flutter test` | **20/20 pass** (biomechanics 4, squat 3, push-up 3, coach 3, l10n 4, platform contract 3). |
| `flutter build apk --debug` (prior run, 2026-11-26) | `build/app/outputs/flutter-apk/app-debug.apk`, 229,294,101 bytes. APK contains the 5,777,746-byte pose task, 46 WAVs, 3 MP4s, 3D JSON and metadata. |
| Model verification | `sha256sum assets/models/pose/pose_landmarker_lite.task` = `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`, matching the manifest. |
| Network/device playback | **Not verified**: no Android device or AVD attached; on-device camera/pose/voice tests are blocked by hardware availability, not by source absence. |

## 4. Actual causes of crashes / broken behaviour

See `docs/engineering/CRASH_ROOT_CAUSE.md` for reproduction steps, stack/path evidence,
root cause, required change and regression test for each item. Summary:

1. **Unhandled native platform exception on workout start** — `LiveWorkoutScreen.initState`
   calls `startCamera()` in a `.then()` with no error handler. Any CameraX/MediaPipe failure
   (`PreviewView not attached`, permission denied, no camera) escapes as an uncaught async
   exception and takes down the Flutter UI.
2. **Permission flow cannot recover** — `camera.requestPermission` returns
   `{granted: false, pending: true}`; the calibration screen immediately sets a permanent error
   and never polls `camera.getStatus` or re-requests after the system dialog closes.
3. **Single reused native preview view** — the platform-view factory returns the same
   `PreviewView` object for every view id and stops the camera on `dispose()`. Navigating
   calibration → workout → calibration breaks camera identity/lifecycle.
4. **Voice assets are addressed with the wrong Flutter asset prefix** — `audioplayers`
   receives `audio/en/foo.wav` instead of `assets/audio/en/foo.wav`, so offline speech silently
   fails (caught by a broad `on Object`). This is a functional crash of the coaching path.
5. **No lifecycle observer** — background/foreground, low memory, audio interruption and
   model unload are not handled; resources remain active or are released at arbitrary times.
6. **History is not encrypted end-to-end** — the native AES-GCM bridge exists but
   `WorkoutDatabase` writes plaintext JSON. Settings "export" is a snackbar, not an export.
7. **No onboarding/readiness/plan/model-manager/visual-mode screens** — the app jumps from
   home straight to calibration; 18 required screens do not exist. Several library entries are
   inert placeholders.
8. **iOS preview is source-only and would show a blank view** (no `previewLayer` attach).
9. **TCN pipeline is not runnable as written** — `nn.Chomp1d` does not exist in PyTorch, so the
   `hasattr` check silently selects `Identity`, leaving causal padding in the residual and
   mismatching tensor lengths. No dependencies/checkpoint exist to train/evaluate it.

## 5. Constraints and blockers discovered

- **No physical device, no AVD, no macOS/Xcode.** Real camera frames, real rep counting from a
  person, on-device inference timing, offline airplane-mode runs, audio playback and iOS
  compilation cannot be claimed as tested here. They remain explicit blockers.
- Qwen3.5-0.8B is a hybrid `qwen35` multimodal architecture, not a plain transformer. Its
  mobile llama.cpp compatibility must be verified against actual runtime support before any
  integration; it is not silently substituted.
- IndicConformer ships NeMo checkpoints; mobile use requires ONNX export + a runtime such as
  sherpa-onnx and per-language licence review. No verified mobile checkpoint/bundle was found
  in the repository, so ASR must not be advertised yet.
- Dataset licences (RepCount, FLAG3D) are not verified for the intended use, so no TCN training
  data was downloaded or fabricated.
- The eSpeak NG generated WAVs are GPL-adjacent assets; distribution obligations need review.

## 6. Deliberately preserved

The deterministic biomechanics engines, event schema, verified pose model, Kotlin CameraX +
MediaPipe bridge, secure Keystore primitive, dark theme, offline WAV/MP4 assets and Python TCN
source were retained. They are repair targets, not discarded work.

## 7. First executable milestone

**M1 — Stability.** Fix the crash paths above, add lifecycle-aware camera/pose ownership,
introduce persistent settings, wire encrypted storage, make the project analyze cleanly, and
keep the APK buildable. M0 documentation is committed with the first M1 patch.
