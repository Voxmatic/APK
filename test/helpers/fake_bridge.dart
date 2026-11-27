import 'dart:convert';

import 'package:ai_gym_trainer/core/platform/pose_channel.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/biomechanics.dart';

/// Deterministic native bridge for unit/widget tests. Every method records its
/// calls so lifecycle ordering can be asserted without an Android device.
class FakePlatformBridge implements PlatformBridge {
  FakePlatformBridge({
    this.startResult = PlatformResult.success,
    this.initResult = PlatformResult.success,
    this.permissionResult = const PlatformResult(ok: true, granted: true),
    this.stopResult = PlatformResult.success,
    this.cameraStatusValue = const CameraStatus(
      running: false,
      permissionGranted: true,
    ),
    this.poseStatusValue = const PoseRuntimeStatus(
      running: true,
      modelId: 'pose_landmarker_lite',
      backend: 'test',
      modelReady: true,
    ),
    this.deviceInfoValue = const DeviceInfo(
      platform: 'test',
      cameraAvailable: true,
    ),
    this.freeSpace = 1024 * 1024 * 1024,
  });

  PlatformResult startResult;
  PlatformResult initResult;
  PlatformResult permissionResult;
  PlatformResult stopResult;
  CameraStatus cameraStatusValue;
  PoseRuntimeStatus poseStatusValue;
  DeviceInfo deviceInfoValue;
  int freeSpace;
  bool failEncrypt = false;
  bool failDecrypt = false;

  final List<String> calls = <String>[];

  @override
  Future<PlatformResult> initializeCamera({
    String camera = 'front',
    int targetFps = 30,
  }) async {
    calls.add('initialize');
    return initResult;
  }

  @override
  Future<PlatformResult> startCamera() async {
    calls.add('start');
    return startResult;
  }

  @override
  Future<PlatformResult> stopCamera() async {
    calls.add('stop');
    return stopResult;
  }

  @override
  Future<CameraStatus> cameraStatus() async => cameraStatusValue;

  @override
  Future<PlatformResult> requestCameraPermission() async {
    calls.add('permission');
    return permissionResult;
  }

  @override
  Future<PlatformResult> openAppSettings() async {
    calls.add('settings');
    return PlatformResult.success;
  }

  @override
  Stream<PoseFrame> poseStream() => const Stream.empty();

  @override
  Stream<SystemEvent> systemStream() => const Stream.empty();

  @override
  Future<PoseRuntimeStatus> poseStatus() async => poseStatusValue;

  @override
  Future<PlatformResult> unloadModel() async => PlatformResult.success;

  @override
  Future<DeviceInfo> deviceInfo() async => deviceInfoValue;

  @override
  Future<int> freeStorageBytes() async => freeSpace;

  @override
  Future<Map<String, dynamic>?> encrypt(String plaintext) async {
    calls.add('encrypt');
    if (failEncrypt) return null;
    return {
      'schema_version': 1,
      'alg': 'AES-256-GCM',
      'iv': 'aXY=',
      'ct': base64.encode(utf8.encode(plaintext)),
    };
  }

  @override
  Future<String?> decrypt(Map<String, dynamic> payload) async {
    calls.add('decrypt');
    if (failDecrypt) return null;
    final ct = payload['ct'] as String? ?? '';
    return utf8.decode(base64.decode(ct));
  }

  @override
  Future<PlatformResult> registerModelFile({
    required String id,
    required String path,
  }) async => PlatformResult.success;

  @override
  Future<PlatformResult> deleteModelFile(String path) async =>
      PlatformResult.success;
}
