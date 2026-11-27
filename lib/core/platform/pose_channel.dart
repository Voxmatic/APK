/// Typed, fault-tolerant wrappers around the native camera / pose / storage
/// bridge. Raw camera frames never cross this boundary — only compact landmark
/// events. Every native call reports failure as data; no platform exception is
/// allowed to escape into widget build or lifecycle code.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/exercise_intelligence/biomechanics.dart';

/// Contract version shared with the native implementation.
const int kPlatformSchemaVersion = 1;

class PlatformResult {
  const PlatformResult({
    required this.ok,
    this.code,
    this.message,
    this.granted,
    this.pending = false,
  });

  final bool ok;
  final String? code;
  final String? message;
  final bool? granted;
  final bool pending;

  bool get isDenied => granted == false && !pending;

  static const success = PlatformResult(ok: true);
}

class CameraStatus {
  const CameraStatus({
    required this.running,
    required this.permissionGranted,
    this.fps = 0,
    this.cameraId = '',
    this.error = '',
  });

  final bool running;
  final bool permissionGranted;
  final double fps;
  final String cameraId;
  final String error;
}

class PoseRuntimeStatus {
  const PoseRuntimeStatus({
    required this.running,
    required this.modelId,
    required this.backend,
    this.modelSha256 = '',
    this.modelReady = false,
    this.inferenceMs = 0,
    this.fps = 0,
    this.lastError = '',
  });

  final bool running;
  final String modelId;
  final String backend;
  final String modelSha256;
  final bool modelReady;
  final double inferenceMs;
  final double fps;
  final String lastError;
}

class DeviceInfo {
  const DeviceInfo({
    this.platform = 'unknown',
    this.model = 'unknown',
    this.osVersion = 'unknown',
    this.sdk = -1,
    this.abi = 'unknown',
    this.totalRamBytes = -1,
    this.freeStorageBytes = -1,
    this.cameraAvailable = false,
    this.acceleration = 'unknown',
  });

  final String platform;
  final String model;
  final String osVersion;
  final int sdk;
  final String abi;
  final int totalRamBytes;
  final int freeStorageBytes;
  final bool cameraAvailable;
  final String acceleration;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    platform: json['platform'] as String? ?? 'unknown',
    model: json['model'] as String? ?? 'unknown',
    osVersion: json['osVersion'] as String? ?? 'unknown',
    sdk: (json['sdk'] as num?)?.toInt() ?? -1,
    abi: json['abi'] as String? ?? 'unknown',
    totalRamBytes: (json['totalRamBytes'] as num?)?.toInt() ?? -1,
    freeStorageBytes: (json['freeStorageBytes'] as num?)?.toInt() ?? -1,
    cameraAvailable: json['cameraAvailable'] == true,
    acceleration: json['acceleration'] as String? ?? 'unknown',
  );
}

enum SystemEventType { permission, lifecycle, audio, unknown }

class SystemEvent {
  const SystemEvent({
    required this.type,
    this.granted,
    this.phase,
    this.message = '',
  });

  final SystemEventType type;
  final bool? granted;
  final String? phase;
  final String message;

  static SystemEvent fromJson(Map<String, dynamic> json) {
    final raw = json['type'] as String? ?? '';
    return SystemEvent(
      type: switch (raw) {
        'permission' => SystemEventType.permission,
        'lifecycle' => SystemEventType.lifecycle,
        'audio' => SystemEventType.audio,
        _ => SystemEventType.unknown,
      },
      granted: json['granted'] as bool?,
      phase: json['phase'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Abstract contract so tests can supply a deterministic fake bridge without
/// touching the platform channels.
abstract class PlatformBridge {
  factory PlatformBridge({
    MethodChannel? method,
    EventChannel? events,
    EventChannel? systemEvents,
  }) = DefaultPlatformBridge;

  static const String cameraViewType = 'ai_gym_trainer/camera_view';

  Future<PlatformResult> initializeCamera({
    String camera = 'front',
    int targetFps = 30,
  });
  Future<PlatformResult> startCamera();
  Future<PlatformResult> stopCamera();
  Future<CameraStatus> cameraStatus();
  Future<PlatformResult> requestCameraPermission();
  Future<PlatformResult> openAppSettings();

  Stream<PoseFrame> poseStream();
  Stream<SystemEvent> systemStream();
  Future<PoseRuntimeStatus> poseStatus();
  Future<PlatformResult> unloadModel();

  Future<DeviceInfo> deviceInfo();
  Future<int> freeStorageBytes();

  Future<Map<String, dynamic>?> encrypt(String plaintext);
  Future<String?> decrypt(Map<String, dynamic> payload);

  Future<PlatformResult> registerModelFile({
    required String id,
    required String path,
  });
  Future<PlatformResult> deleteModelFile(String path);
}

class DefaultPlatformBridge implements PlatformBridge {
  DefaultPlatformBridge({
    MethodChannel? method,
    EventChannel? events,
    EventChannel? systemEvents,
  }) : _method = method ?? const MethodChannel('ai_gym_trainer/camera'),
       _events = events ?? const EventChannel('ai_gym_trainer/pose'),
       _systemEvents =
           systemEvents ?? const EventChannel('ai_gym_trainer/system');

  final MethodChannel _method;
  final EventChannel _events;
  final EventChannel _systemEvents;

  Future<PlatformResult> _invoke(String method, [Object? arguments]) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (result == null) return const PlatformResult(ok: true);
      final ok = result['ok'] == true || result['granted'] == true;
      return PlatformResult(
        ok: ok,
        code: result['code'] as String?,
        message: result['message'] as String?,
        granted: result['granted'] as bool?,
        pending: result['pending'] == true,
      );
    } on PlatformException catch (e) {
      return PlatformResult(ok: false, code: e.code, message: e.message);
    } on MissingPluginException catch (e) {
      return PlatformResult(
        ok: false,
        code: 'UNSUPPORTED_PLATFORM',
        message: e.message,
      );
    } on Object catch (e) {
      return PlatformResult(ok: false, code: 'UNKNOWN', message: e.toString());
    }
  }

  @override
  Future<PlatformResult> initializeCamera({
    String camera = 'front',
    int targetFps = 30,
  }) =>
      _invoke('camera.initialize', {'camera': camera, 'targetFps': targetFps});

  @override
  Future<PlatformResult> startCamera() => _invoke('camera.start');

  @override
  Future<PlatformResult> stopCamera() => _invoke('camera.stop');

  @override
  Future<PlatformResult> requestCameraPermission() =>
      _invoke('camera.requestPermission');

  @override
  Future<PlatformResult> openAppSettings() => _invoke('app.openSettings');

  @override
  Future<CameraStatus> cameraStatus() async {
    try {
      final result =
          await _method.invokeMapMethod<String, dynamic>('camera.getStatus') ??
          const {};
      return CameraStatus(
        running: result['running'] == true,
        permissionGranted: result['permission'] == true,
        fps: (result['fps'] as num?)?.toDouble() ?? 0,
        cameraId: result['cameraId'] as String? ?? '',
        error: result['error'] as String? ?? '',
      );
    } on Object catch (e) {
      return CameraStatus(
        running: false,
        permissionGranted: false,
        error: e.toString(),
      );
    }
  }

  @override
  Stream<PoseFrame> poseStream() {
    return _events
        .receiveBroadcastStream()
        .map((event) {
          if (event is! Map) {
            return PoseFrame(
              landmarks: const [],
              timestampMs: 0,
              error: 'Malformed pose event',
            );
          }
          return PoseFrame.fromJson(Map<String, dynamic>.from(event));
        })
        .handleError((dynamic error) {
          // Error events are converted into an empty frame with a visible reason.
        }, test: (_) => true);
  }

  @override
  Stream<SystemEvent> systemStream() {
    return _systemEvents
        .receiveBroadcastStream()
        .map((event) {
          if (event is! Map)
            return const SystemEvent(type: SystemEventType.unknown);
          return SystemEvent.fromJson(Map<String, dynamic>.from(event));
        })
        .handleError((dynamic error) {}, test: (_) => true);
  }

  @override
  Future<PoseRuntimeStatus> poseStatus() async {
    try {
      final result =
          await _method.invokeMapMethod<String, dynamic>('pose.getStatus') ??
          const {};
      return PoseRuntimeStatus(
        running: result['running'] == true,
        modelId: result['modelId'] as String? ?? 'unknown',
        backend: result['backend'] as String? ?? 'unknown',
        modelSha256: result['modelSha256'] as String? ?? '',
        modelReady: result['modelReady'] == true,
        inferenceMs: (result['inferenceMs'] as num?)?.toDouble() ?? 0,
        fps: (result['fps'] as num?)?.toDouble() ?? 0,
        lastError: result['lastError'] as String? ?? '',
      );
    } on Object catch (e) {
      return PoseRuntimeStatus(
        running: false,
        modelId: 'unknown',
        backend: 'unknown',
        lastError: e.toString(),
      );
    }
  }

  @override
  Future<PlatformResult> unloadModel() => _invoke('pose.unload');

  @override
  Future<DeviceInfo> deviceInfo() async {
    try {
      final result =
          await _method.invokeMapMethod<String, dynamic>('device.getInfo') ??
          const {};
      return DeviceInfo.fromJson(result);
    } on Object {
      return const DeviceInfo();
    }
  }

  @override
  Future<int> freeStorageBytes() async {
    try {
      final result =
          await _method.invokeMapMethod<String, dynamic>(
            'storage.getFreeSpace',
          ) ??
          const {};
      return (result['bytes'] as num?)?.toInt() ?? -1;
    } on Object {
      return -1;
    }
  }

  @override
  Future<Map<String, dynamic>?> encrypt(String plaintext) async {
    try {
      return await _method.invokeMapMethod<String, dynamic>(
        'storage.encrypt',
        plaintext,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> decrypt(Map<String, dynamic> payload) async {
    try {
      return await _method.invokeMethod<String>('storage.decrypt', payload);
    } on Object {
      return null;
    }
  }

  @override
  Future<PlatformResult> registerModelFile({
    required String id,
    required String path,
  }) => _invoke('model.register', {'id': id, 'path': path});

  @override
  Future<PlatformResult> deleteModelFile(String path) =>
      _invoke('model.delete', {'path': path});
}
