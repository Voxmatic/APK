library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../coach/coach_engine.dart';
import '../exercise_intelligence/biomechanics.dart';
import '../exercise_intelligence/events.dart';
import '../visual_learning/skeleton_painter.dart';
import '../workout/workout_controller.dart';
import 'camera_preview.dart';

class LiveWorkoutScreen extends ConsumerStatefulWidget {
  const LiveWorkoutScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends ConsumerState<LiveWorkoutScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  PoseFrame _frame = const PoseFrame(landmarks: [], timestampMs: 0);

  @override
  void initState() {
    super.initState();
    final id = ExerciseId.values.firstWhere(
      (e) => e.wireName == widget.exerciseId,
      orElse: () => ExerciseId.squat,
    );
    ref.read(workoutControllerProvider.notifier).start(id);
    ref.read(platformBridgeProvider).initializeCamera().then((_) {
      ref.read(platformBridgeProvider).startCamera();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(platformBridgeProvider).stopCamera();
    super.dispose();
  }

  void _finish() {
    final controller = ref.read(workoutControllerProvider.notifier);
    controller.stop();
    controller.saveSession();
    context.go('/summary');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final state = ref.watch(workoutControllerProvider);

    ref.listen(poseStreamProvider, (_, next) {
      final frame = next.value;
      if (frame != null) {
        _frame = frame;
        ref.read(workoutControllerProvider.notifier).onPoseFrame(frame);
      }
    });

    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final exerciseKey = state.exercise?.wireName ?? widget.exerciseId;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CameraPreviewWidget(),
            if (_frame.hasFullBody)
              CustomPaint(
                painter: SkeletonPainter(
                  frame: _frame,
                  mirrored: true,
                  showGhost: true,
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _HudChip(label: s.get(exerciseKey), value: ''),
                        const Spacer(),
                        _HudChip(
                          label: s.get('reps'),
                          value: '${state.reps}',
                          emphasize: true,
                        ),
                        const SizedBox(width: 8),
                        _HudChip(
                          label: s.get('duration'),
                          value: '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),
                  if (state.instruction != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        s.get(state.instruction!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (state.demoId != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.ghost),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill, color: AppColors.ghost, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.get('show_demo'), style: const TextStyle(fontSize: 12))),
                          TextButton(
                            onPressed: () => context.go('/library'),
                            child: Text(s.get('view_demo'), style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (!state.running)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s.get('paused'), style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final c = ref.read(workoutControllerProvider.notifier);
                              state.running ? c.pause() : c.resume();
                            },
                            icon: Icon(state.running ? Icons.pause : Icons.play_arrow),
                            label: Text(state.running ? s.get('pause') : s.get('resume')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _finish,
                            icon: const Icon(Icons.check),
                            label: Text(s.get('finish')),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(voiceServiceProvider).speak(
                            const CoachInstruction(id: 'pain_stop', phraseKey: 'pain_stop', priority: 100, stopWorkout: true),
                          );
                      _finish();
                    },
                    icon: const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 16),
                    label: Text(s.get('pain_stop'), style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: emphasize ? AppColors.primary : Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(value,
                style: TextStyle(
                  color: emphasize ? AppColors.primary : Colors.white,
                  fontSize: emphasize ? 22 : 14,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ],
      ),
    );
  }
}
