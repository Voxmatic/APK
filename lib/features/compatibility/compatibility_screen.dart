/// Device readiness gate. All values come from the native bridge; unknown
/// values are shown as unknown instead of being guessed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/model_catalog.dart';
import '../../core/platform/pose_channel.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class CompatibilityScreen extends ConsumerStatefulWidget {
  const CompatibilityScreen({super.key});

  @override
  ConsumerState<CompatibilityScreen> createState() =>
      _CompatibilityScreenState();
}

class _CompatibilityScreenState extends ConsumerState<CompatibilityScreen> {
  DeviceInfo _device = const DeviceInfo();
  PoseRuntimeStatus _pose = const PoseRuntimeStatus(
    running: false,
    modelId: 'unknown',
    backend: 'unknown',
  );
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bridge = ref.read(platformBridgeProvider);
    final device = await bridge.deviceInfo();
    final pose = await bridge.poseStatus();
    if (!mounted) return;
    setState(() {
      _device = device;
      _pose = pose;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final ramOk =
        _device.totalRamBytes < 0 ||
        _device.totalRamBytes >= 2 * 1024 * 1024 * 1024;
    final storageOk =
        _device.freeStorageBytes < 0 ||
        _device.freeStorageBytes > 150 * 1024 * 1024;
    final checks = <(String, bool, String)>[
      (
        s.get('device_camera'),
        _device.cameraAvailable,
        _device.cameraAvailable ? _device.model : 'unavailable',
      ),
      (
        s.get('device_ram'),
        ramOk,
        _device.totalRamBytes < 0
            ? 'unknown'
            : formatBytes(_device.totalRamBytes),
      ),
      (
        s.get('device_storage'),
        storageOk,
        _device.freeStorageBytes < 0
            ? 'unknown'
            : formatBytes(_device.freeStorageBytes),
      ),
      (
        s.get('model_readiness'),
        _pose.modelId == 'pose_landmarker_lite',
        _pose.modelId,
      ),
      (s.get('device_acceleration'), true, _pose.backend),
    ];
    final ready = checks.every((c) => c.$2);

    return Scaffold(
      appBar: AppBar(title: Text(s.get('compatibility'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.get(ready ? 'ready_for_workouts' : 'not_ready'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: ready ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(height: 18),
              if (!_loaded)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: checks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final (label, ok, detail) = checks[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            ok
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: ok ? AppColors.success : AppColors.accent,
                          ),
                          title: Text(label),
                          subtitle: Text(
                            detail,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _loaded ? () => context.go('/models') : null,
                child: Text(s.get('model_install')),
              ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(s.get('nav_home')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
