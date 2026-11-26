# Development Environment Audit

Audit performed: 2026-11-26. Workspace: `/mnt/c/Users/91832/Pictures/Mtrain` (empty at start).

## Host / OS

| Item | Detected |
|---|---|
| Kernel | `Linux AkashGroup 6.18.58.1-microsoft-standard-WSL2 x86_64` |
| Distribution | Ubuntu 24.04.5 LTS (Noble), WSL2 |
| Windows host | Windows 11 user profile `C:\Users\91832` |
| Shell | bash (WSL2), PowerShell 5.1 and cmd.exe accessible |

## Toolchain

| Requirement | Detected | Status |
|---|---|---|
| Flutter | Installed during this session at `/home/akkash/flutter` (stable, 3.50.1, revision `ae9b586f34`). | OK (WSL) |
| Dart | Bundled with Flutter SDK, 3.14.0 | OK |
| Java (WSL, system) | Ubuntu OpenJDK 17.0.20.1 — **JRE only**, no `javac` | INSUFFICIENT for AGP toolchains |
| Java (WSL, installed) | Temurin 17.0.21.1 JDK at `/home/akkash/tools/jdk17` (has `javac`) | OK — used for all builds |
| Java (Windows) | `C:\Program Files\Java\jdk-17`, Java 17.0.14 (has `javac.exe`) | OK |
| Android SDK (Windows) | `C:\Users\91832\AppData\Local\Android\Sdk` — only `.exe` build tools; build-tools 36.0.0 reported corrupted by Linux Gradle | UNSUITABLE for Linux builds |
| Android SDK (Linux, installed) | `/home/akkash/android-sdk` with platform 36, build-tools 36.0.0, platform-tools, NDK 28.2.13676358 (symlink to Linux NDK previously downloaded into the Windows SDK path), CMake 3.22.1 | OK — used for build |
| adb | Linux `platform-tools/adb` installed; Windows `adb.exe` present; `adb devices` returned **no devices** | Device test BLOCKED |
| Emulator | `emulator.exe` present; `emulator -list-avds` returned **no AVDs** | Emulator test BLOCKED |
| Gradle | 9.5.0 wrapper; distribution fetched with curl (229 MB) because Java DNS failed. `gradle.properties` now sets `-Djava.net.preferIPv4Stack=true`, `org.gradle.daemon=false`, workers=2, heap 1536 MB. | OK |
| Git | 2.43.0 (WSL), Git for Windows in PATH | OK |
| Python (WSL) | 3.12.3 | OK |
| Python (Windows) | 3.10 (user install) | OK |
| pip (WSL) | Not installed (`ensurepip` missing) | BLOCKED for Python ML deps |
| PyTorch | Not installed | NOT_STARTED — training cannot run yet |
| ONNX Runtime | Not installed | NOT_STARTED |
| ffmpeg | Downloaded static build to `/home/akkash/tools` (outside repo) during setup | OK for demo asset generation |
| eSpeak NG | Debian 1.52.0 packages extracted (no sudo) to `/home/akkash/tools/espeak-deb/extracted`; wrapper at `/home/akkash/tools/espeak-ng-wrapper.sh` | OK — generated 46 WAVs |
| GPU (host) | Intel UHD Graphics 620, NVIDIA GeForce MX110 2 GB | WSL GPU compute not assumed |
| CPU (host) | Intel Core i5-8250U (8 vCPU visible to WSL) | OK |
| Host RAM | 8.5 GB physical; WSL reports 3.8 GB, 8 GB swap | Tight for Gradle + emulator simultaneously |
| Disk | WSL ext4: ~936 GB free; Windows C:: ~20 GB free (92% used) | Models/SDK builds kept off C: where possible |

## Notable findings

1. The PATH contained a stale entry `/mnt/c/flutter/src/flutter/bin`; no Flutter SDK existed there.
   Flutter was installed into the WSL home directory instead, because C: has only 20 GB free.
2. A Windows Android SDK exists but contains only Windows `.exe` build tools. Linux Gradle reported
   "Build Tools revision 36.0.0 is corrupted"; a native Linux SDK was installed at
   `/home/akkash/android-sdk` and `ANDROID_HOME` now points there for all builds.
3. No physical Android device and no AVD are attached. Native camera/pose and on-device benchmarks
   are therefore **BLOCKED** in this environment. The APK was built successfully and is ready for
   device testing.
4. iOS compilation, signing and device testing require macOS + Xcode. iOS source is prepared but
   verification is **BLOCKED** on Linux/Windows, as required by the specification.
5. `sudo apt-get` requires a password, so system packages were avoided; self-contained binaries were
   downloaded/built into `/home/akkash/tools` instead.
6. Network access to `storage.googleapis.com` and `huggingface.co` was verified (HTTP 200).
7. Python ML dependencies need `pip` bootstrapped into a user `venv` before training (see commands below).
8. Java DNS resolution initially failed for `services.gradle.org`; `-Djava.net.preferIPv4Stack=true` in
   `android/gradle.properties` fixed it. The Gradle distribution and all Android SDK packages were
   then fetched successfully.

## Exact installation / setup commands

```bash
# Flutter (already performed)
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /home/akkash/flutter
export PATH=/home/akkash/flutter/bin:$PATH
export JAVA_HOME=/home/akkash/tools/jdk17
export PATH=$JAVA_HOME/bin:$PATH
export ANDROID_HOME=/home/akkash/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
flutter --version
flutter doctor -v
flutter config --android-sdk "$ANDROID_HOME"

# Android device (when one is available)
"$ANDROID_HOME/platform-tools/adb.exe" devices
# Create an AVD from Windows if desired, then:
"$ANDROID_HOME/emulator/emulator.exe" -avd <avd_name>

# Python ML environment ( pip bootstrap )
curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
python3 /tmp/get-pip.py --user
python3 -m venv ~/.venvs/aitrainer
source ~/.venvs/aitrainer/bin/activate
pip install numpy torch onnx onnx2tf tensorflow scikit-learn

# Model download (explicit only)
python3 scripts/download_models.py --group pose
python3 scripts/verify_models.py

# Build
flutter pub get
flutter test
flutter build apk --debug
```

## Compatibility matrix

| Component | Minimum | Present | Note |
|---|---|---|---|
| Android SDK platform | 36 (compileSdk for Flutter 3.50) | 36 (Linux SDK) | Uses 36 |
| Java for AGP 8 | 17 JDK (with javac) | Temurin 17.0.21.1 | Compatible |
| MediaPipe Tasks Vision | Android API 24+ | minSdk 26 | Compatible |
| Flutter | 3.x | stable | Compatible |
| iOS | Xcode 15+ | absent | macOS required |
