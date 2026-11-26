# Testing Plan and Results

## Status legend

`NOT_STARTED` · `IN_PROGRESS` · `IMPLEMENTED` · `TESTED` · `VERIFIED_ON_DEVICE` · `BLOCKED`

## Automated tests (run with `flutter test`)

| Test | Covers | Status |
|---|---|---|
| `test/unit/biomechanics_test.dart` | Joint angles, missing landmarks, visibility | TESTED (4/4 pass) |
| `test/unit/squat_engine_test.dart` | Full rep, shallow movement, sequential reps | TESTED (3/3 pass) |
| `test/unit/pushup_engine_test.dart` | Full rep, hip sag, alignment rejection | TESTED (3/3 pass) |
| `test/unit/coach_policy_test.dart` | Pain override, cooldown, visual demo mapping | TESTED (3/3 pass) |
| `test/unit/localization_test.dart` | en/hi strings, 13-language catalogue, fallback | TESTED (4/4 pass) |
| `test/integration/platform_contract_test.dart` | Pose frame parsing, versioned rep/form events | TESTED (3/3 pass) |

Total: **20/20 tests passing** (`flutter test`, 2026-11-26).

Not written (status `NOT_STARTED`): a widget test for HUD rendering from synthetic
events. The pure-Dart engine and serialization layers are covered; widget-level
coverage is deferred until device verification. Do not claim it as implemented.

## Integration / device tests

| Test | Status | Reason |
|---|---|---|
| Camera initialization on physical phone | BLOCKED | No device/emulator attached (`adb devices` empty) |
| MediaPipe model load on device | BLOCKED | Same |
| Real squat/push-up validation | BLOCKED | Same |
| Voice playback on device | BLOCKED | Same |
| Offline airplane-mode workout | BLOCKED | Same |
| iOS build/signing | BLOCKED | macOS/Xcode required |

Run these after connecting a device:

```bash
flutter test
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
adb devices
python3 scripts/benchmark_models.py --device <serial> --iterations 50
```

## AI validation (pending data)

Metrics to report after participant-independent evaluation: exercise precision/recall, phase accuracy,
rep-count MAE, form-error precision/recall, false-positive correction rate, confidence calibration.
No accuracy percentage is claimed until `ml/exercise_recognition/evaluation_report.json` exists.
Python ML environment currently lacks `numpy`/`torch`/`onnxruntime` (status `BLOCKED`).

## Measured environment

See `docs/ENVIRONMENT_AUDIT.md`. Tool versions and test output from this session are appended below.

### Build and test log (2026-11-26)

```
$ flutter --version
Flutter 3.50.1 • channel stable • framework ae9b586f34 • engine 51379e6df48ea8ee7205623b90fe66491cad8df3
Dart 3.14.0

$ flutter analyze
19 issues found (all info: material.dart deprecations, withOpacity, unnecessary_underscores,
use_build_context_synchronously). 0 errors, 0 warnings.

$ flutter test
00:02 +20: All tests passed!

$ python3 scripts/generate_voice_assets.py --espeak /home/akkash/tools/espeak-ng-wrapper.sh
Generated 46 offline phrase assets (6875.8 KiB)

$ python3 scripts/generate_demo_assets.py
created squat_front.mp4 (32 KiB), squat_side.mp4 (33 KiB), pushup_side.mp4 (22 KiB),
squat_3d.json (3.8 KiB)

$ flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk  (219 MB)

APK inspection: pose_landmarker_lite.task 5,777,746 bytes; 46 en/hi WAV phrases;
3 demo MP4s; squat_3d.json; exercises.json — all present under
assets/flutter_assets/assets/.
```

### Environment fixes applied during this run (evidence)

- Gradle wrapper distribution was incomplete; `gradle-9.5.0-all.zip` (229 MB) fetched
  with curl into `~/.gradle/wrapper/dists/...` because Java DNS initially failed on
  `services.gradle.org`. Adding `-Djava.net.preferIPv4Stack=true` to `gradle.properties`
  resolved Java DNS.
- System Java was JRE-only; Temurin JDK 17.0.21.1 installed at `/home/akkash/tools/jdk17`.
- Windows Android SDK contains only `.exe` build tools; native Linux SDK installed at
  `/home/akkash/android-sdk` (platform 36, build-tools 36.0.0, platform-tools,
  NDK 28.2.13676358 symlinked from the already-downloaded Linux NDK, CMake 3.22.1).
- Kotlin fixes: `PoseProcessor.context` made a constructor property; `ByteBuffer.rewind()`
  split to avoid `Buffer`/`ByteBuffer` type mismatch; nullable `ImageAnalysis` unwrapped
  before `bindToLifecycle`.
- Demo generator had an infinite loop in Bresenham `line()` when interpolating floats
  with differing fractional parts; endpoints now rounded to integers (0.016 s/frame).
