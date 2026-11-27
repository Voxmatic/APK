/// Serialized camera ownership. Calibration, workout and lifecycle handlers
/// all go through one queue, so a late `stop()` can never race a new `start()`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workout/workout_controller.dart';
import 'pose_channel.dart';

class CameraSession {
  CameraSession(this._bridge);

  final PlatformBridge _bridge;
  Future<void> _tail = Future.value();
  bool _started = false;

  bool get isStarted => _started;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then((_) => null, onError: (_) => null);
    return next;
  }

  /// Requests permission only when needed, initializes once, then starts.
  /// Every failure is returned as data; nothing escapes to a widget lifecycle.
  Future<PlatformResult> start({String camera = 'front', int targetFps = 30}) =>
      _enqueue(() async {
        if (_started) return PlatformResult.success;
        final status = await _bridge.cameraStatus();
        if (!status.permissionGranted) {
          final permission = await _bridge.requestCameraPermission();
          if (!permission.ok) return permission;
          if (permission.pending || permission.isDenied) {
            return PlatformResult(
              ok: false,
              code: 'PERMISSION_PENDING',
              message: 'Waiting for camera permission',
              granted: false,
              pending: permission.pending,
            );
          }
        }
        final init = await _bridge.initializeCamera(
          camera: camera,
          targetFps: targetFps,
        );
        if (!init.ok) return init;
        final started = await _bridge.startCamera();
        if (started.ok) _started = true;
        return started;
      });

  Future<PlatformResult> stop() => _enqueue(() async {
    if (!_started) return PlatformResult.success;
    final result = await _bridge.stopCamera();
    if (result.ok) _started = false;
    return result;
  });

  Future<PlatformResult> restart() async {
    await stop();
    return start();
  }
}

final cameraSessionProvider = Provider<CameraSession>(
  (ref) => CameraSession(ref.watch(platformBridgeProvider)),
);
