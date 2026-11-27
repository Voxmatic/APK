/// Between-set rest timer driven by the authoritative workout state.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import 'workout_controller.dart';

class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<RestScreen> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final state = ref.watch(workoutControllerProvider);
    final remainingMs =
        state.restUntilMs - DateTime.now().millisecondsSinceEpoch;
    final seconds = remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;

    return Scaffold(
      appBar: AppBar(title: Text(s.get('rest_between_sets'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.self_improvement, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                seconds > 0 ? '$seconds s' : s.get('ready'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium
                    ?.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 12),
              Text(
                '${s.get('set_complete_label')} · ${state.setsCompleted}/${state.targetSets}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: () {
                  ref.read(workoutControllerProvider.notifier).nextSet();
                  context.go('/workout/${widget.exerciseId}');
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(s.get('next_set')),
              ),
              TextButton(
                onPressed: () => context.go('/summary'),
                child: Text(s.get('finish')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
