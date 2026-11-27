/// Local workout history with simple aggregate charts computed from stored
/// sessions. No server is contacted.
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
    final totalReps = _rows.fold<int>(0, (sum, r) => sum + r.reps);
    final totalMinutes =
        _rows.fold<int>(0, (sum, r) => sum + r.durationMs) ~/ 60000;
    final maxReps = _rows.isEmpty
        ? 1
        : _rows.map((r) => r.reps).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(s.get('nav_progress'))),
      body: _rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  s.get('no_sessions'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: s.get('reps'), value: '$totalReps'),
                      _Stat(
                        label: s.get('sets'),
                        value:
                            '${_rows.fold<int>(0, (sum, r) => sum + r.sets)}',
                      ),
                      _Stat(
                        label: s.get('duration'),
                        value: '${totalMinutes}m',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final row in _rows.take(12))
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Container(
                                height: 10 + 100 * (row.reps / maxReps),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._rows.map((row) {
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      row.startedAt,
                    );
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryDim,
                          child: Text(
                            '${row.reps}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(s.get(row.exercise)),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} · ${row.durationMs ~/ 60000} min',
                        ),
                        trailing: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                      ),
                    );
                  }),
                ],
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
          fontSize: 24,
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
