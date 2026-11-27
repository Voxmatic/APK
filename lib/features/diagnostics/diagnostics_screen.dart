/// Runtime diagnostics read from the native bridge. Values are never invented.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/model_catalog.dart';
import '../../core/platform/pose_channel.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  DeviceInfo _device = const DeviceInfo();
  CameraStatus _camera = const CameraStatus(
    running: false,
    permissionGranted: false,
  );
  PoseRuntimeStatus _pose = const PoseRuntimeStatus(
    running: false,
    modelId: 'unknown',
    backend: 'unknown',
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bridge = ref.read(platformBridgeProvider);
    final device = await bridge.deviceInfo();
    final camera = await bridge.cameraStatus();
    final pose = await bridge.poseStatus();
    if (!mounted) return;
    setState(() {
      _device = device;
      _camera = camera;
      _pose = pose;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final rows = <(String, String)>[
      (
        'Platform',
        '${_device.platform} ${_device.osVersion} (SDK ${_device.sdk})',
      ),
      (
        s.get('device_ram'),
        _device.totalRamBytes < 0
            ? 'unknown'
            : formatBytes(_device.totalRamBytes),
      ),
      (
        s.get('device_storage'),
        _device.freeStorageBytes < 0
            ? 'unknown'
            : formatBytes(_device.freeStorageBytes),
      ),
      ('ABI', _device.abi),
      (
        s.get('device_camera'),
        '${_device.cameraAvailable} · running=${_camera.running}',
      ),
      (s.get('device_acceleration'), _pose.backend),
      ('Pose model', '${_pose.modelId} · ready=${_pose.modelReady}'),
      (
        'Model SHA-256',
        _pose.modelSha256.isEmpty ? 'unknown' : _pose.modelSha256,
      ),
      ('Inference', '${_pose.inferenceMs.toStringAsFixed(1)} ms'),
      (s.get('camera_error'), _camera.error.isEmpty ? 'none' : _camera.error),
      (s.get('pose_error'), _pose.lastError.isEmpty ? 'none' : _pose.lastError),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.get('diagnostics'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        child: const Icon(Icons.refresh),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppColors.surfaceAlt),
          itemBuilder: (context, index) => ListTile(
            title: Text(rows[index].$1, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              rows[index].$2,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
