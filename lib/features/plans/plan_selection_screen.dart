/// Local, deterministic workout plans. Selecting a plan only changes a
/// preference on this device; no recommendation engine or server is involved.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/workout_plan.dart';
import '../exercise_intelligence/events.dart';

class PlanSelectionScreen extends ConsumerWidget {
  const PlanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final s = AppStrings(settings.language);
    return Scaffold(
      appBar: AppBar(title: Text(s.get('select_plan'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.get('plan'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: availablePlans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = availablePlans[index];
                    final selected = plan.id == settings.selectedPlanId;
                    return Card(
                      color: selected
                          ? AppColors.primaryDim
                          : AppColors.surface,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: selected
                              ? AppColors.primary
                              : AppColors.surfaceAlt,
                          child: Icon(
                            selected ? Icons.check : Icons.fitness_center,
                            color: selected
                                ? Colors.black
                                : AppColors.textMuted,
                          ),
                        ),
                        title: Text(s.get(plan.nameKey)),
                        subtitle: Text(
                          '${s.get(plan.descriptionKey)} · ${plan.entries.length} exercises',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => ref
                            .read(settingsControllerProvider.notifier)
                            .selectPlan(plan.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final plan = planById(settings.selectedPlanId);
                  context.go('/calibration/${plan.first.exercise.wireName}');
                },
                child: Text(s.get('start_exercise')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
