library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/workout_db.dart';
import '../workout/workout_controller.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  List<WorkoutSessionRecord> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await ref.read(workoutDatabaseProvider).history();
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    return Scaffold(
      appBar: AppBar(title: Text(s.get('nav_progress'))),
      body: _rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(s.get('no_sessions'), textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = _rows[index];
                final date = DateTime.fromMillisecondsSinceEpoch(row.startedAt);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryDim,
                      child: Text('${row.reps}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(s.get(row.exercise)),
                    subtitle: Text('${date.day}/${date.month}/${date.year}  ·  ${row.durationMs ~/ 60000} min'),
                    trailing: const Icon(Icons.check_circle_outline, color: AppColors.success),
                  ),
                );
              },
            ),
    );
  }
}
