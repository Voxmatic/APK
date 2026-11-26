# Device compatibility

Status: **IN_PROGRESS** — desktop build and static verification pass; on-device
verification is **BLOCKED** (no Android device or AVD attached in the build
environment). Do not read any line below as a device-tested claim unless it is
explicitly marked `VERIFIED_ON_DEVICE`.

## Requirements

| Item | Minimum | Reason |
|---|---|---|
| Android | 8.0 / API 26 | CameraX + MediaPipe Tasks Vision baseline |
| RAM | 3 GB recommended | Pose Landmarker Lite + Flutter engine |
| Camera | Front-facing, 720p+ | Full-body framing for squat/push-up landmarks |
| Storage | ~250 MB free (debug APK 219 MB) | APK + local workout database |
| GPU | Not required | Inference runs on CPU delegate by design |

## Build-time verified (Linux, 2026-11-26)

- Flutter `3.50.1` stable, Dart `3.14.0`.
- JDK: Temurin 17.0.21.1 (javac required by AGP toolchains).
- Gradle `9.5.0` (wrapper distribution pinned in `gradle-wrapper.properties`).
- Android SDK: platform 36, build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1 — all
  installed into a **native Linux** SDK at `/home/akkash/android-sdk`. The Windows
  SDK at `/mnt/c/.../Android/Sdk` contains only `.exe` build tools and cannot be
  used by Linux Gradle.
- `flutter analyze`: 0 errors (deprecation infos only).
- `flutter test`: 20/20 passing.
- `flutter build apk --debug`: `build/app/outputs/flutter-apk/app-debug.apk` (219 MB).
- APK inspection confirms bundled `pose_landmarker_lite.task` (5,777,746 bytes),
  46 English/Hindi WAV phrases, 3 demo MP4s, squat 3D JSON, and exercise metadata.

## On-device matrix (pending)

| Device class | Status | Notes |
|---|---|---|
| Pixel 6 / Android 14+ | NOT_STARTED | Reference target for pose latency |
| Mid-range Snapdragon 6xx / Android 10 | NOT_STARTED | Check CPU inference < 40 ms |
| Budget 2 GB RAM / Android 8.1 | BLOCKED | Likely below recommended RAM |
| Emulator (API 35, x86_64) | BLOCKED | No AVD installed; `emulator -list-avds` empty |
| iOS (any) | BLOCKED | Requires macOS + Xcode; source prepared only |

## How to verify on a device

1. `adb install build/app/outputs/flutter-apk/app-debug.apk`
2. Grant camera permission when prompted; stand 2–3 m from the front camera in
   even light so head-to-ankle landmarks are visible.
3. In Settings → Diagnostics, confirm `pose.getStatus` reports
   `modelSha256 = 59929e1d…` and `running = true`.
4. Run 3 squats and 3 push-ups; confirm rep counter increments exactly once per
   full repetition and no correction fires during clean form.
5. `python3 scripts/benchmark_models.py --device <serial> --iterations 50`.
6. Record results here with the `VERIFIED_ON_DEVICE` status and the exact device
   model / Android version. Until then the status stays `IN_PROGRESS`.

## Known limitations

- Debug APK includes arm64-v8a, armeabi-v7a and x86_64 libraries (hence 219 MB).
  A release split APK per ABI will be substantially smaller.
- The optional Qwen3.5-0.8B GGUF model is **not** bundled and is never loaded
  during a workout; `qwen35` hybrid-architecture mobile support is unvalidated.
- iOS sources exist under `ios/` but are not compiled or signed in this Linux
  environment.
