library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../exercise_intelligence/events.dart';
import '../workout/workout_controller.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(settingsProvider));
    final state = ref.watch(workoutControllerProvider);
    final minutes =
        (state.startedAtMs == 0
            ? 0
            : DateTime.now().millisecondsSinceEpoch - state.startedAtMs) ~/
        60000;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.get('summary')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: s.get('reps'), value: '${state.reps}'),
                      _Stat(
                        label: s.get('sets'),
                        value: '${state.setsCompleted}',
                      ),
                      _Stat(
                        label: s.get('duration'),
                        value: state.durationMs > 0
                            ? '${state.durationMs ~/ 60000}m'
                            : '${minutes}m',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                s.get('privacy'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (state.formEvents.isEmpty)
                const Text(
                  'No form corrections recorded.',
                  style: TextStyle(color: AppColors.success),
                ),
              ...state.formEvents.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.formError(e.error.wireName),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    ],
  );
}
