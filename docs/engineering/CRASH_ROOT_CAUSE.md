# Crash root-cause register (M0)

Status key: `REPRODUCED_IN_HARNESS`, `STATIC_CONFIRMED`, `BLOCKED_ON_DEVICE`.
"No device attached" means the on-device stack trace cannot be captured in this environment;
it does **not** mean the defect is absent.

---

## C1 — Uncaught platform error when starting the workout camera

- **Severity:** crash (Flutter red screen / process-level error handler).
- **Reproduction steps:**
  1. Launch the app on a device with camera denied, no camera, or before `PreviewView` is laid out.
  2. Open an exercise → calibration → Start (or deep-link `/workout/squat`).
  3. `LiveWorkoutScreen.initState` runs `initializeCamera().then((_) => startCamera())`.
- **Exception path:** `PlatformException(INVALID_STATE, PreviewView is not attached)` (or
  `PERMISSION_DENIED`/`CameraUnavailableException`) from `camera.start`. It is thrown inside a
  `Future.then` with no `catchError`, so it reaches `FlutterError.onError`.
- **Root cause:** method-channel failures are treated as impossible; no `try/catch`, no UI error
  state, no retry. Native `CameraController.start()` also reads `previewView.display.rotation`
  before the view has a window, and silently swallows its own exceptions (`catch (_: Exception)`).
- **Required change:** make all bridge calls return typed results or throw caught exceptions;
  move camera start into an async lifecycle controller with error states; derive rotation from
  the activity window with a safe fallback; surface retry/permission UI.
- **Regression test:** `test/widget/camera_lifecycle_test.dart` injects a `PlatformException`
  from `camera.start` and asserts the screen shows an error + retry button instead of crashing.
- **Status:** `REPRODUCED_IN_HARNESS` (instrumented channel) / `BLOCKED_ON_DEVICE` (real stack trace).

## C2 — Permission denial is permanent

- **Severity:** functional dead end; user cannot start a workout after granting permission.
- **Reproduction:** deny camera permission at the system dialog; grant it in Settings; return to
  the calibration screen. `_error` remains `camera_permission` and Start stays disabled.
- **Root cause:** `camera.requestPermission` returns `granted: false, pending: true` but Dart
  stores only `false`. There is no `WidgetsBindingObserver`, no polling of `camera.getStatus`,
  and no `onRequestPermissionsResult` event forwarded to Dart.
- **Required change:** activity forwards permission results on an EventChannel; Dart observes
  app lifecycle and re-checks permission on resume; dedicated Permissions screen with retry.
- **Regression test:** widget test pumps `PermissionScreen` with denied → granted stream and
  asserts enabled CTA.
- **Status:** `STATIC_CONFIRMED`.

## C3 — Platform view instance reuse

- **Severity:** intermittent black preview / native `IllegalStateException` risk on navigation.
- **Reproduction:** calibration (view created) → start workout (old view disposed, new view
  requested) → back to calibration. Factory `create()` always returns the same `previewView`.
- **Root cause:** one `PreviewView` object is shared by every platform-view id; `dispose()` calls
  `cameraController.stop()` and `poseProcessor.stop()`, so lifecycle is tied to a stale view.
- **Required change:** create a fresh `PreviewView` per platform view; keep camera/pose ownership
  in a singleton controller that is started only after the view is attached (`doOnAttach`).
- **Regression test:** native contract test + repeated start/stop stress script (device).
- **Status:** `STATIC_CONFIRMED` / `BLOCKED_ON_DEVICE`.

## C4 — Offline voice never plays

- **Severity:** core coaching feature silently absent.
- **Reproduction:** trigger any coach instruction with bundled assets; no sound.
- **Root cause:** Flutter assets are registered as `assets/audio/<lang>/<key>.wav`;
  `VoiceService` calls `AssetSource('audio/<lang>/<key>.wav')`. `audioplayers` cannot find the
  asset. The `on Object` handler hides the failure, and the localization guard returns early for
  keys missing from `AppStrings` (e.g. `camera_hint`, `control_movement`, `body_alignment`).
- **Required change:** use the full asset path, expand the key catalogue, verify playback by
  checking the player's completion event (not merely the absence of an exception), handle audio
  focus/interruption.
- **Regression test:** unit test asserts resolved `AssetSource` paths exist in the asset manifest
  and all coach phrase keys resolve; widget/device test for playback.
- **Status:** `STATIC_CONFIRMED` / `BLOCKED_ON_DEVICE`.

## C5 — Background/resource lifecycle missing

- **Severity:** camera/model stay active in background; stale frames after resume; possible
  `CameraX` bind errors on rotation or app restart.
- **Root cause:** no `WidgetsBindingObserver`, no `onPause/onResume` handling in plugin, no
  explicit unload of the pose landmarker.
- **Required change:** pause inference and stop camera on background/inactive; re-initialize on
  resume if a workout is active; release model on app teardown; expose status to UI.
- **Regression test:** lifecycle widget test toggles `AppLifecycleState` and verifies bridge
  calls; device stress test.
- **Status:** `STATIC_CONFIRMED`.

## C6 — History "encryption" is not connected

- **Severity:** privacy guarantee in `docs/PRIVACY.md` is false for persisted payloads.
- **Root cause:** `WorkoutDatabase.saveSession` writes `jsonEncode(payload)`; `SecureCrypto`
  bridge is unused. Settings export only shows a snackbar.
- **Required change:** injectable `PayloadCipher` using native AES-GCM; versioned envelope;
  decrypt on read; real local export/delete; regression tests with a fake cipher.
- **Status:** `STATIC_CONFIRMED`.

## C7 — TCN training pipeline cannot run

- **Severity:** model preparation blocked.
- **Root cause:** `nn.Chomp1d` does not exist in PyTorch; `hasattr` silently substitutes
  `Identity`, so causal padding is never removed and residual shapes diverge after the first
  block. There is no dataset, no checkpoint, no evaluation report and no Python environment.
- **Required change:** use the project's own `Chomp1d` (declared below in the file), add shape
  assertions/smoke test, install dependencies in an isolated venv, do not claim training without
  a licensed participant-split dataset.
- **Status:** `STATIC_CONFIRMED`.

---

## Evidence captured

```
$ flutter --version        -> Flutter 3.50.1 / Dart 3.14.0
$ flutter analyze          -> 19 info, 0 errors
$ flutter test             -> 20/20 passed
$ adb devices -l           -> no devices
$ sha256sum pose_landmarker_lite.task
  -> 59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a
$ ls -l build/app/outputs/flutter-apk/app-debug.apk
  -> 229294101 bytes
```

The instrumented widget reproduction for C1 is `test/widget/crash_repro_test.dart`. The Flutter
test environment cannot instantiate a real CameraX platform view, so it injects the exact native
method-channel error; the production fix is validated by the same channel contract in
`test/widget/camera_lifecycle_test.dart`.
