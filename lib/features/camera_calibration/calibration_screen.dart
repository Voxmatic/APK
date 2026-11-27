/// Camera calibration with recoverable permissions and typed error states.
/// No platform exception can escape into build or initState.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/platform/camera_session.dart';
import '../../core/platform/pose_channel.dart';
import '../../core/theme/app_theme.dart';
import '../exercise_intelligence/biomechanics.dart';
import '../exercise_intelligence/events.dart';
import '../live_workout/camera_preview.dart';
import '../visual_learning/skeleton_painter.dart';
import '../workout/workout_controller.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  PoseFrame _frame = const PoseFrame(landmarks: [], timestampMs: 0);
  double _visibility = 0;
  bool _initializing = true;
  bool _awaitingPermission = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestAndStart();
  }

  Future<void> _requestAndStart() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
      _awaitingPermission = false;
    });
    final result = await ref.read(cameraSessionProvider).start();
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _error = result.code ?? result.message ?? 'camera_error';
        _awaitingPermission = result.pending;
        _initializing = false;
      });
      return;
    }
    setState(() => _initializing = false);
  }

  Future<void> _openSettings() async {
    await ref.read(platformBridgeProvider).openAppSettings();
  }

  void _onPose(PoseFrame frame) {
    const required = <int>[
      LandmarkIndex.leftShoulder,
      LandmarkIndex.rightShoulder,
      LandmarkIndex.leftHip,
      LandmarkIndex.rightHip,
      LandmarkIndex.leftKnee,
      LandmarkIndex.rightKnee,
      LandmarkIndex.leftAnkle,
      LandmarkIndex.rightAnkle,
    ];
    final visibility = Biomechanics.visibility(frame, required);
    if (!mounted) return;
    setState(() {
      _frame = frame;
      _visibility = visibility;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    ref.listen(poseStreamProvider, (_, next) {
      final frame = next.value;
      if (frame != null) _onPose(frame);
    });
    ref.listen(systemEventsProvider, (_, next) {
      final event = next.value;
      if (event?.type == SystemEventType.permission && mounted) {
        if (event!.granted == true) _requestAndStart();
        if (event.granted == false) {
          setState(() {
            _error = 'camera_permission';
            _awaitingPermission = false;
            _initializing = false;
          });
        }
      }
    });

    final ready = _visibility >= 0.62 && _error == null && !_initializing;
    final exercise = ExerciseId.values.firstWhere(
      (e) => e.wireName == widget.exerciseId,
      orElse: () => ExerciseId.squat,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.get('calibration'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_error == null)
                        ref.watch(cameraPreviewBuilderProvider)(),
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.no_photography,
                                  size: 40,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _awaitingPermission
                                      ? s.get('permission_camera_body')
                                      : '${s.get('camera_error')}: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.text),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      onPressed: _requestAndStart,
                                      child: Text(s.get('retry')),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _openSettings,
                                      child: Text(s.get('open_settings')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_initializing)
                        const Center(child: CircularProgressIndicator()),
                      if (_frame.hasFullBody)
                        CustomPaint(
                          painter: SkeletonPainter(
                            frame: _frame,
                            mirrored: true,
                          ),
                        ),
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ready ? s.get('ready') : s.get('calibration_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ready ? AppColors.success : AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _visibility.clamp(0.0, 1.0),
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceAlt,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                '${s.get('confidence')}: ${(_visibility * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ready
                    ? () => context.go('/workout/${exercise.wireName}')
                    : null,
                child: Text(s.get('start')),
              ),
              TextButton(
                onPressed: () => context.go('/library'),
                child: Text(s.get('cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ref.read(cameraSessionProvider).stop();
    super.dispose();
  }
}
