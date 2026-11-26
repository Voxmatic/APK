library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final bridge = ref.read(platformBridgeProvider);
    final granted = await bridge.requestCameraPermission();
    if (!granted && mounted) {
      setState(() {
        _error = 'camera_permission';
        _initializing = false;
      });
      return;
    }
    await bridge.initializeCamera();
    await bridge.startCamera();
    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    ref.read(platformBridgeProvider).stopCamera();
    super.dispose();
  }

  void _onPose(PoseFrame frame) {
    final required = <int>[
      LandmarkIndex.leftShoulder, LandmarkIndex.rightShoulder,
      LandmarkIndex.leftHip, LandmarkIndex.rightHip,
      LandmarkIndex.leftKnee, LandmarkIndex.rightKnee,
      LandmarkIndex.leftAnkle, LandmarkIndex.rightAnkle,
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

    final ready = _visibility >= 0.62;
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
                      if (_error == null) const CameraPreviewWidget(),
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(s.get('permission_camera'), textAlign: TextAlign.center),
                          ),
                        ),
                      if (_initializing) const Center(child: CircularProgressIndicator()),
                      if (_frame.hasFullBody)
                        CustomPaint(painter: SkeletonPainter(frame: _frame, mirrored: true)),
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              Text('${s.get('confidence')}: ${(_visibility * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ready && _error == null
                    ? () {
                        final id = ExerciseId.values.firstWhere(
                          (e) => e.wireName == widget.exerciseId,
                          orElse: () => ExerciseId.squat,
                        );
                        context.go('/workout/${id.wireName}');
                      }
                    : null,
                child: Text(s.get('start')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
