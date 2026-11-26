library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../exercise_intelligence/events.dart';
import '../workout/workout_controller.dart';

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(settingsProvider));
    final entries = <(ExerciseId, String, String, bool)>[
      (ExerciseId.squat, 'squat', 'assets/exercises/videos/squat_front.mp4', true),
      (ExerciseId.pushup, 'pushup', 'assets/exercises/videos/pushup_side.mp4', true),
      (ExerciseId.bicepCurl, 'bicep_curl', '', false),
      (ExerciseId.lunge, 'lunge', '', false),
      (ExerciseId.shoulderPress, 'shoulder_press', '', false),
      (ExerciseId.plank, 'plank', '', false),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.get('nav_library'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final (id, key, demo, ready) = entries[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              leading: CircleAvatar(
                backgroundColor: ready ? AppColors.primaryDim : AppColors.surfaceAlt,
                child: Icon(ready ? Icons.fitness_center : Icons.construction,
                    color: ready ? AppColors.primary : AppColors.textMuted),
              ),
              title: Text(s.get(key), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(ready ? s.get('start_workout') : s.get('in_development'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: ready
                  ? const Icon(Icons.chevron_right, color: AppColors.primary)
                  : const Icon(Icons.lock_outline, color: AppColors.textMuted),
              onTap: ready ? () => context.go('/calibration/${id.wireName}') : null,
            ),
          );
        },
      ),
    );
  }
}
