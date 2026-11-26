/// Typed wrappers around the native camera / pose platform channels.
/// Raw camera frames never cross this boundary — only compact landmark events.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/exercise_intelligence/biomechanics.dart';

/// Contract version shared with the native implementation.
const int kPlatformSchemaVersion = 1;

class CameraStatus {
  const CameraStatus({required this.running, required this.permissionGranted, this.fps = 0});

  final bool running;
  final bool permissionGranted;
  final double fps;
}

class PoseRuntimeStatus {
  const PoseRuntimeStatus({
    required this.running,
    required this.modelId,
    required this.backend,
    this.modelSha256 = '',
  });

  final bool running;
  final String modelId;
  final String backend;
  final String modelSha256;
}

class PlatformBridge {
  PlatformBridge({MethodChannel? method, EventChannel? events})
      : _method = method ?? const MethodChannel('ai_gym_trainer/camera'),
        _events = events ?? const EventChannel('ai_gym_trainer/pose');

  final MethodChannel _method;
  final EventChannel _events;

  static const String cameraViewType = 'ai_gym_trainer/camera_view';

  Future<bool> initializeCamera({String camera = 'front', int targetFps = 30}) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'camera.initialize',
      {'camera': camera, 'targetFps': targetFps},
    );
    return result?['ok'] == true;
  }

  Future<void> startCamera() => _method.invokeMethod<void>('camera.start');

  Future<void> stopCamera() => _method.invokeMethod<void>('camera.stop');

  Future<CameraStatus> cameraStatus() async {
    final result = await _method.invokeMapMethod<String, dynamic>('camera.getStatus') ?? const {};
    return CameraStatus(
      running: result['running'] == true,
      permissionGranted: result['permission'] == true,
      fps: (result['fps'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<bool> requestCameraPermission() async {
    final result = await _method.invokeMapMethod<String, dynamic>('camera.requestPermission');
    return result?['granted'] == true;
  }

  Stream<PoseFrame> poseStream() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is! Map) return const PoseFrame(landmarks: [], timestampMs: 0);
      return PoseFrame.fromJson(Map<String, dynamic>.from(event));
    });
  }

  Future<PoseRuntimeStatus> poseStatus() async {
    final result = await _method.invokeMapMethod<String, dynamic>('pose.getStatus') ?? const {};
    return PoseRuntimeStatus(
      running: result['running'] == true,
      modelId: result['modelId'] as String? ?? 'unknown',
      backend: result['backend'] as String? ?? 'unknown',
      modelSha256: result['modelSha256'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> secureEncrypt(String plaintext) async {
    final result = await _method.invokeMapMethod<String, dynamic>('storage.encrypt', plaintext);
    return result ?? const {};
  }

  Future<String> secureDecrypt(Map<String, dynamic> payload) async {
    final result = await _method.invokeMethod<String>('storage.decrypt', payload);
    return result ?? '';
  }
}
