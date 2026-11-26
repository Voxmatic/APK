library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/workout_db.dart';
import '../workout/workout_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<WorkoutSessionRecord> _history = const [];

  @override
  void initState() {
    super.initState();
    ref.read(workoutDatabaseProvider).history(limit: 5).then((rows) {
      if (mounted) setState(() => _history = rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final totalReps = _history.fold<int>(0, (sum, r) => sum + r.reps);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.get('app_name')),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryDim.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 14, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(s.get('offline_badge'), style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Text(s.get('welcome'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(s.get('subtitle'), style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 32),
              SizedBox(
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF123A3A), Color(0xFF141B26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.self_improvement, size: 58, color: AppColors.primary.withOpacity(0.9)),
                        const SizedBox(height: 10),
                        Text('${_history.length} sessions · $totalReps reps',
                            style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(s.get('start_workout')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.video_library_outlined),
                label: Text(s.get('view_demo')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.surfaceAlt),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
