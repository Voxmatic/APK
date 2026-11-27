/// Live workout screen. Camera start is awaited and every native failure is
/// rendered as a retryable state; rep counting comes only from real frames.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/workout_plan.dart';
import '../exercise_intelligence/biomechanics.dart';
import '../exercise_intelligence/events.dart';
import '../visual_learning/ghost_trainer.dart';
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
  int _tick = 0;
  PoseFrame _frame = const PoseFrame(landmarks: [], timestampMs: 0);
  bool _starting = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Provider writes and camera start are deferred until after the first
    // frame: modifying a provider in initState is a Riverpod lifecycle error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = ExerciseId.values.firstWhere(
        (e) => e.wireName == widget.exerciseId,
        orElse: () => ExerciseId.squat,
      );
      final settings = ref.read(settingsControllerProvider);
      final plan = planById(settings.selectedPlanId);
      ref.read(workoutControllerProvider.notifier).startFromPlan(plan, id);
      _startCamera();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() => _starting = true);
    final ok = await ref.read(workoutControllerProvider.notifier).beginCamera();
    if (mounted) setState(() => _starting = false);
    if (!ok && mounted && !context.mounted) return;
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final controller = ref.read(workoutControllerProvider.notifier);
    await controller.endCamera();
    controller.stop();
    await controller.saveSession();
    if (mounted && context.mounted) context.go('/summary');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsControllerProvider).language);
    final state = ref.watch(workoutControllerProvider);
    final ghost = ref.watch(
      ghostClipProvider(state.exercise?.wireName ?? widget.exerciseId),
    );
    final visualization = ref
        .watch(settingsControllerProvider)
        .visualizationMode;

    ref.listen(poseStreamProvider, (_, next) {
      final frame = next.value;
      if (frame != null) {
        _frame = frame;
        ref.read(workoutControllerProvider.notifier).onPoseFrame(frame);
      }
    });
    ref.listen(systemEventsProvider, (_, next) {
      final event = next.value;
      if (event != null) {
        ref.read(workoutControllerProvider.notifier).handleSystemEvent(event);
      }
    });

    final elapsedMs = state.durationMs > 0
        ? state.durationMs
        : state.startedAtMs == 0
        ? 0
        : DateTime.now().millisecondsSinceEpoch - state.startedAtMs + _tick;
    final minutes = elapsedMs ~/ 60000;
    final seconds = (elapsedMs ~/ 1000) % 60;
    final exerciseKey = state.exercise?.wireName ?? widget.exerciseId;
    final remainingMs =
        state.restUntilMs - DateTime.now().millisecondsSinceEpoch;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ref.watch(cameraPreviewBuilderProvider)(),
            if (_frame.hasFullBody)
              CustomPaint(
                painter: SkeletonPainter(
                  frame: _frame,
                  mirrored: true,
                  showGhost: visualization == VisualizationMode.ghost,
                ),
              ),
            if (visualization == VisualizationMode.ghost && ghost.value != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: GhostTrainerPainter(
                    clip: ghost.value!,
                    timeMilliseconds:
                        DateTime.now().millisecondsSinceEpoch + _tick,
                    mirrored: true,
                    opacity: 0.6,
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _HudChip(label: s.get(exerciseKey), value: ''),
                        const Spacer(),
                        _HudChip(
                          label: s.get('reps'),
                          value: '${state.setReps}/${state.targetReps}',
                          emphasize: true,
                        ),
                        const SizedBox(width: 8),
                        _HudChip(
                          label: s.get('duration'),
                          value:
                              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),
                  if (state.cameraError.isNotEmpty)
                    _Banner(
                      text: '${s.get('camera_error')}: ${state.cameraError}',
                      color: AppColors.accent,
                      action: OutlinedButton(
                        onPressed: _startCamera,
                        child: Text(s.get('retry')),
                      ),
                    ),
                  if (state.poseError.isNotEmpty)
                    _Banner(
                      text: '${s.get('pose_error')}: ${state.poseError}',
                      color: AppColors.warning,
                    ),
                  if (_starting && state.cameraError.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  if (state.instruction != null)
                    _Banner(
                      text: s.get(state.instruction!),
                      color: AppColors.accent,
                    ),
                  if (state.demoId != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.ghost),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_fill,
                            color: AppColors.ghost,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.get('show_demo'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(
                              '/demo/${state.exercise?.wireName ?? widget.exerciseId}',
                            ),
                            child: Text(
                              s.get('view_demo'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (remainingMs > 0)
                    _Banner(
                      text:
                          '${s.get('rest_between_sets')} ${(remainingMs / 1000).ceil()}s',
                      color: AppColors.primary,
                      action: TextButton(
                        onPressed: () => context.push(
                          '/rest/${state.exercise?.wireName ?? widget.exerciseId}',
                        ),
                        child: Text(s.get('next_set')),
                      ),
                    ),
                  const Spacer(),
                  if (!state.running &&
                      state.cameraError.isEmpty &&
                      !state.isFinished)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.get('paused'),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final c = ref.read(
                                workoutControllerProvider.notifier,
                              );
                              state.running ? c.pause() : c.resume();
                            },
                            icon: Icon(
                              state.running ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(
                              state.running ? s.get('pause') : s.get('resume'),
                            ),
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
                    onPressed: () async {
                      await ref
                          .read(workoutControllerProvider.notifier)
                          .reportPain();
                      if (mounted) _finish();
                    },
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    label: Text(
                      s.get('pain_stop'),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                      ),
                    ),
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

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, this.action});

  final String text;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

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
        border: Border.all(
          color: emphasize ? AppColors.primary : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: emphasize ? AppColors.primary : Colors.white,
                fontSize: emphasize ? 20 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
