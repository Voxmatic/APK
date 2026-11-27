/// Local, deterministic workout plans. No server, no recommendations based on
/// uploaded data; the user selects a plan and every target comes from here.
library;

import '../features/exercise_intelligence/events.dart';

class PlanEntry {
  const PlanEntry({
    required this.exercise,
    required this.targetReps,
    required this.targetSets,
    this.restSeconds = 45,
  });

  final ExerciseId exercise;
  final int targetReps;
  final int targetSets;
  final int restSeconds;
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.entries,
  });

  final String id;
  final String nameKey;
  final String descriptionKey;
  final List<PlanEntry> entries;

  PlanEntry get first => entries.first;
}

const List<WorkoutPlan> availablePlans = [
  WorkoutPlan(
    id: 'beginner',
    nameKey: 'plan_beginner',
    descriptionKey: 'plan_beginner_desc',
    entries: [
      PlanEntry(
        exercise: ExerciseId.squat,
        targetReps: 8,
        targetSets: 2,
        restSeconds: 45,
      ),
      PlanEntry(
        exercise: ExerciseId.pushup,
        targetReps: 5,
        targetSets: 2,
        restSeconds: 60,
      ),
    ],
  ),
  WorkoutPlan(
    id: 'strength',
    nameKey: 'plan_strength',
    descriptionKey: 'plan_strength_desc',
    entries: [
      PlanEntry(
        exercise: ExerciseId.squat,
        targetReps: 12,
        targetSets: 3,
        restSeconds: 60,
      ),
      PlanEntry(
        exercise: ExerciseId.pushup,
        targetReps: 8,
        targetSets: 3,
        restSeconds: 60,
      ),
    ],
  ),
  WorkoutPlan(
    id: 'quick',
    nameKey: 'plan_quick',
    descriptionKey: 'plan_quick_desc',
    entries: [
      PlanEntry(
        exercise: ExerciseId.squat,
        targetReps: 10,
        targetSets: 1,
        restSeconds: 30,
      ),
      PlanEntry(
        exercise: ExerciseId.pushup,
        targetReps: 10,
        targetSets: 1,
        restSeconds: 30,
      ),
    ],
  ),
];

WorkoutPlan planById(String id) => availablePlans.firstWhere(
  (p) => p.id == id,
  orElse: () => availablePlans.first,
);
