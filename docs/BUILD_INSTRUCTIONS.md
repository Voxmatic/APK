# Build Instructions

## Prerequisites

- Flutter stable (tested with SDK at `/home/akkash/flutter`; Flutter 3.50.1 / Dart 3.14.0)
- **JDK 17 with `javac`** (a JRE is not enough for AGP toolchains). Tested with Temurin 17.0.21.1 at `/home/akkash/tools/jdk17`.
- Gradle 9.5.0 (wrapper distribution pinned). If Java DNS fails in WSL, add `-Djava.net.preferIPv4Stack=true` to `android/gradle.properties`.
- **Native Linux Android SDK** at `/home/akkash/android-sdk` with platform 36, build-tools 36.0.0, platform-tools, NDK 28.2.13676358, CMake 3.22.1.
  - The Windows SDK at `/mnt/c/Users/91832/AppData/Local/Android/Sdk` contains only `.exe` build tools and **cannot** be used from Linux Gradle. Install Linux tools with `cmdline-tools` + `sdkmanager` as done in this run.

```bash
export PATH=/home/akkash/flutter/bin:$PATH
export JAVA_HOME=/home/akkash/tools/jdk17
export PATH=$JAVA_HOME/bin:$PATH
export ANDROID_HOME=/home/akkash/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

To recreate the Linux SDK:

```bash
# Download commandlinetools-linux-11076708_latest.zip from dl.google.com, unzip to
# $ANDROID_HOME/cmdline-tools/latest, then:
sdkmanager --sdk_root=$ANDROID_HOME 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
```

## Models

The MediaPipe Lite task is placed at `assets/models/pose/pose_landmarker_lite.task` (5.5 MB) and
declared as a Flutter asset. No other model is required for the workout path.

To re-download/verify explicitly:

```bash
python3 scripts/download_models.py --group pose
python3 scripts/verify_models.py
```

Optional LLM:

```bash
python3 scripts/download_models.py --group llm   # 563 MB, explicit only
```

## Build and test

```bash
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
# output: build/app/outputs/flutter-apk/app-debug.apk
```

Release AAB requires a signing key:

```bash
flutter build appbundle --release
```

## Install

```bash
"$ANDROID_HOME/platform-tools/adb" install -r build/app/outputs/flutter-apk/app-debug.apk
```

## iOS

On macOS with Xcode 15+:

```bash
cd ios
pod install --repo-update
cd ..
flutter build ios --release --no-codesign
# signing + TestFlight/App Store require an Apple Developer account
```

iOS native sources mirror the Android channel contracts; they cannot be compiled on Linux/Windows.

## First-run flow

1. Grant camera permission.
2. Select language (English/Hindi) and voice.
3. Stand back so the full body is visible in the calibration screen.
4. Start workout; choose Squat or Push-up.
5. Perform the exercise; watch skeleton/ghost; listen to offline coaching.
6. View summary and progress; data remains on device.
