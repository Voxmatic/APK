# Build Instructions

## Prerequisites

- Flutter stable (tested: `/home/akkash/flutter`, Flutter 3.50.1 / Dart 3.14.0).
- **JDK 17 with `javac`** (a JRE is not enough). Tested: Temurin 17.0.21.1 at
  `/home/akkash/tools/jdk17`.
- Gradle 9.5.0 wrapper. If Java DNS fails in WSL, keep
  `-Djava.net.preferIPv4Stack=true` in `android/gradle.properties`.
- **Native Linux Android SDK** at `/home/akkash/android-sdk` with platform 36,
  build-tools 36.0.0, platform-tools, NDK 28.2.13676358 and CMake 3.22.1.
  The Windows SDK at `/mnt/c/.../Android/Sdk` contains only `.exe` build tools
  and cannot be used from Linux Gradle.

```bash
export PATH=/home/akkash/flutter/bin:/home/akkash/tools/jdk17/bin:$PATH
export ANDROID_HOME=/home/akkash/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export JAVA_HOME=/home/akkash/tools/jdk17
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

To recreate the Linux SDK:

```bash
sdkmanager --sdk_root=$ANDROID_HOME 'platform-tools' 'platforms;android-36' \
  'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
```

## Models

The MediaPipe Lite task is bundled at
`assets/models/pose/pose_landmarker_lite.task` (5,777,746 bytes) and declared
as a Flutter asset. Its SHA-256 is pinned in both
`assets/models/manifest.json` and native Kotlin code. No other model is
required for the workout path.

Optional artifacts are installed only from the app's model manager after
explicit consent; each download checks free space, size and SHA-256 before
registration. The desktop downloader remains available for development:

```bash
python3 scripts/download_models.py --group pose
python3 scripts/verify_models.py
```

Do not use `--group llm` unless you intend to download ~563 MB and validate
`qwen35` mobile runtime support; it is not part of the shipped workout flow.

## Build and test

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
# build/app/outputs/flutter-apk/app-debug.apk

flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk (debug-signed for local validation)

cd android && ./gradlew :app:testDebugUnitTest
```

A production App Bundle requires your own signing key; replace the temporary
release `signingConfig = debug` in `android/app/build.gradle.kts` first.

## Install

```bash
"$ANDROID_HOME/platform-tools/adb" install -r \
  build/app/outputs/flutter-apk/app-debug.apk
```

## iOS

On macOS with Xcode 15+ and MediaPipeTasksVision added via SPM:

```bash
cd ios && pod install --repo-update && cd ..
flutter build ios --release --no-codesign
```

Signing/TestFlight require an Apple Developer account. The iOS bridge is
source-prepared only; it has not been compiled or device-tested on Linux.

## First-run flow

1. Onboarding (privacy explanation), then camera permission with retry/settings.
2. Device readiness and model verification.
3. Select language, voice and plan; calibrate full-body visibility.
4. Start squat or push-up; watch live skeleton or 3D ghost; use the local demo.
5. Finish; review summary and progress. Export/delete data from Settings.
