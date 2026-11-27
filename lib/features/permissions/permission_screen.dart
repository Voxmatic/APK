/// Camera permission screen with real grant/denial recovery.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/platform/pose_channel.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _granted = false;
  bool _pending = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final status = await ref.read(platformBridgeProvider).cameraStatus();
    if (!mounted) return;
    setState(() {
      _granted = status.permissionGranted;
      _message = status.error;
    });
  }

  Future<void> _request() async {
    final result = await ref
        .read(platformBridgeProvider)
        .requestCameraPermission();
    if (!mounted) return;
    setState(() {
      _granted = result.granted == true;
      _pending = result.pending;
      _message = result.message ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    ref.listen(systemEventsProvider, (_, next) {
      final event = next.value;
      if (event?.type == SystemEventType.permission && mounted) {
        setState(() {
          _granted = event!.granted == true;
          _pending = false;
          _message = event.message;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(s.get('permissions'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _granted ? Icons.verified_user : Icons.camera_alt_outlined,
                size: 84,
                color: _granted ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                s.get(_granted ? 'permission_granted' : 'permissions'),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                s.get('permission_camera_body'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              if (!_granted) ...[
                FilledButton.icon(
                  onPressed: _pending ? null : _request,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(s.get('grant_permission')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(platformBridgeProvider).openAppSettings(),
                  child: Text(s.get('open_settings')),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: Text('Continue without camera'),
                ),
              ] else
                FilledButton(
                  onPressed: () => context.go('/compatibility'),
                  child: Text(s.get('start')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
