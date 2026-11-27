# Testing Plan and Results

Status legend: `NOT_STARTED` · `IN_PROGRESS` · `IMPLEMENTED` · `TESTED` ·
`VERIFIED_ON_DEVICE` · `BLOCKED`.

## Flutter tests (`flutter test --timeout 60s`, 2026-11-27)

**Result: 32/32 passing.**

| Test file | Covers | Status |
|---|---|---|
| `test/unit/biomechanics_test.dart` | Joint angles, missing landmarks, visibility | TESTED (4/4) |
| `test/unit/squat_engine_test.dart` | Full rep, shallow rejection, sequential reps | TESTED (3/3) |
| `test/unit/pushup_engine_test.dart` | Full rep, hip sag, alignment rejection | TESTED (3/3) |
| `test/unit/coach_policy_test.dart` | Pain override, cooldown, visual demo mapping | TESTED (3/3) |
| `test/unit/localization_test.dart` | en/hi translations, fallback, all UI keys resolve | TESTED (5/5) |
| `test/unit/model_catalog_test.dart` | Bundled manifest checksum/size, disk guard, byte format | TESTED (3/3) |
| `test/unit/ghost_trainer_test.dart` | Squat/push-up 3D keyframe interpolation and looping | TESTED (2/2) |
| `test/unit/workout_controller_test.dart` | Real-frame set completion, encrypted persistence, permission denial, malformed frames | TESTED (3/3) |
| `test/integration/platform_contract_test.dart` | Pose frame parsing, versioned rep/form events | TESTED (3/3) |
| `test/widget/camera_lifecycle_test.dart` | Native start failure UI, successful start, pending permission | TESTED (3/3) |

The original M0 crash repro (`crash_repro_test.dart`) was replaced by
`camera_lifecycle_test.dart`: it injects the exact native failure as typed
data and asserts no Flutter/platform error escapes the widget tree.

## Native Kotlin tests

```bash
cd android
./gradlew :app:testDebugUnitTest
```

`NativeContractTest` passes 2/2:
- channel names and schema version match the Dart bridge;
- the SHA-256 pinned in native code matches `assets/models/manifest.json`.

The full Gradle `test` task also runs plugin unit tests and fails in an
upstream dependency: `shared_preferences_android:SharedPreferencesTest` uses
Robolectric SDK 36, which requires Java 21 (this environment has JDK 17).
This is documented, not masked. The app's own native unit tests pass.

## Static analysis and builds (2026-11-27)

```
$ flutter analyze
0 errors, 0 warnings (informational lints only).

$ flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk  (249 MB)

$ flutter build apk --release
✓ Built build/app/outputs/flutter-apk/app-release.apk (115.8 MB, debug-signed)

$ aapt dump badging app-debug.apk
package=com.aitrainer.gymtrainer.ai_gym_trainer versionCode=1 versionName=1.0.0
sdkVersion=26 targetSdkVersion=36
uses-permission: android.permission.CAMERA
```

Earlier Kotlin compile error (`Image.Plane` vs `ImageProxy.PlaneProxy`) was
fixed; both debug and release APKs now build successfully.

## Integration / device tests

| Test | Status | Reason |
|---|---|---|
| Camera initialization on physical phone | BLOCKED | `adb devices -l` empty; no AVD installed |
| MediaPipe model load and latency on device | BLOCKED | Same |
| Real squat/push-up accuracy | BLOCKED | Same |
| Voice playback on device | BLOCKED | Same |
| Offline airplane-mode workout | BLOCKED | Same |
| APK install/launch on device | BLOCKED | Same |
| iOS build/signing | BLOCKED | macOS/Xcode required |

After connecting a device:

```bash
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb devices
python3 scripts/benchmark_models.py --device <serial> --iterations 50
```

## AI validation

No accuracy number is claimed. Required metrics after a participant-independent
evaluation exist: exercise precision/recall, phase accuracy, rep-count MAE,
form-error precision/recall, false-positive correction rate, and confidence
calibration. Status stays `BLOCKED` until `evaluation_report.json` exists and
Python ML dependencies (`numpy`, `torch`, `onnxruntime`) are available.

Generated asset evidence: 54 WAV phrases (27 en + 27 hi), 3 demo MP4s,
2 authored 3D ghost clips, and the verified 5,777,746-byte pose task.
