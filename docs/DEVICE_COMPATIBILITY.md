# Device compatibility

Status: **IN_PROGRESS** — desktop build and static verification pass;
on-device verification is **BLOCKED** (no Android device or AVD attached).
Nothing below is device-tested unless explicitly marked `VERIFIED_ON_DEVICE`.

## Requirements

| Item | Minimum | Reason |
|---|---|---|
| Android | 8.0 / API 26 | CameraX + MediaPipe Tasks Vision baseline |
| RAM | 3 GB recommended | Pose Landmarker Lite + Flutter engine |
| Camera | Front-facing, 720p+ | Full-body framing for squat/push-up landmarks |
| Storage | ~260 MB free (debug APK 249 MB) | APK + local workout database |
| GPU | Not required | CPU delegate by design |

## Build-time verified (Linux, 2026-11-27)

- Flutter 3.50.1 stable, Dart 3.14.0.
- Temurin JDK 17.0.21.1 (`javac` required by AGP).
- Gradle 9.5.0 wrapper; AGP 9.3.1; Kotlin 2.4.20.
- Native Linux Android SDK: platform 36, build-tools 36.0.0, platform-tools,
  NDK 28.2.13676358, CMake 3.22.1.
- `flutter analyze`: 0 errors, 0 warnings.
- `flutter test`: 32/32 passing (including camera lifecycle widget tests).
- `./gradlew :app:testDebugUnitTest`: 2/2 Kotlin contract tests passing.
- `flutter build apk --debug`: 249 MB; `flutter build apk --release`: 115.8 MB
  (release signed with the debug key for local validation only).
- APK manual inspection: verified pose task, 54 WAV phrases, 3 demo MP4s,
  2 ghost JSON clips and exercise metadata are bundled under Flutter assets.
- `NativeContractTest` verifies native channel names and the pinned pose SHA-256.

## On-device matrix (pending)

| Device class | Status | Notes |
|---|---|---|
| Pixel 6 / Android 14+ | NOT_STARTED | Reference target for pose latency |
| Mid-range Snapdragon 6xx / Android 10 | NOT_STARTED | Check CPU inference < 40 ms |
| Budget 2 GB RAM / Android 8.1 | BLOCKED | Below recommended RAM |
| Emulator (API 35, x86_64) | BLOCKED | No AVD installed (`emulator -list-avds` empty) |
| iOS (any) | BLOCKED | Requires macOS + Xcode; source prepared only |

## How to verify on a device

1. `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
2. Complete onboarding, grant camera permission, and stand 2–3 m from the front
   camera in even light so head-to-ankle landmarks are visible.
3. In Settings → Diagnostics, confirm the pose model id is
   `pose_landmarker_lite`, `modelReady=true`, and the SHA-256 starts with
   `59929e1d`.
4. Run 3 squats and 3 push-ups; confirm each full repetition increments once
   and clean form produces no false correction.
5. Toggle skeleton / 3D ghost / demo video; confirm overlay playback.
6. Enable airplane mode and repeat a full workout; confirm no outbound traffic.
7. `python3 scripts/benchmark_models.py --device <serial> --iterations 50`.
8. Record results here with exact device model and Android version. Until then
   statuses stay unchanged.

## Known limitations

- Debug APK includes arm64-v8a, armeabi-v7a and x86_64 libraries (hence 249 MB).
  A per-ABI release split is substantially smaller.
- Release APK currently uses the debug signing config; a production key is
  required before Play Store distribution.
- Optional Qwen3.5-0.8B GGUF is not bundled and is never loaded during a workout;
  `qwen35` hybrid-architecture mobile support is unvalidated.
- iOS source exists under `ios/`, but is not compiled or signed in this
  Linux/Windows environment.
- No verified offline ASR bundle is included; on-screen controls are authoritative.
