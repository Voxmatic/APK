import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/features/coach/coach_engine.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/events.dart';

void main() {
  test('pain always stops coaching regardless of cooldown', () {
    final coach = CoachEngine();
    coach.process(
      const RepCompletedEvent(
        exercise: ExerciseId.squat,
        timestampMs: 1000,
        repCount: 5,
        phase: MovementPhase.standing,
      ),
    );
    final stop = coach.process(
      const FormCorrectionEvent(
        exercise: ExerciseId.squat,
        timestampMs: 1100,
        error: FormError.kneesCollapsingInward,
        severity: 'warning',
      ),
      userReportedPain: true,
    );
    expect(stop?.stopWorkout, isTrue);
    expect(stop?.phraseKey, 'pain_stop');
  });

  test('cooldown suppresses repeated corrections', () {
    final coach = CoachEngine(cooldownMs: 2000);
    final event = FormCorrectionEvent(
      exercise: ExerciseId.squat,
      timestampMs: 1000,
      error: FormError.kneesCollapsingInward,
      severity: 'warning',
    );
    expect(coach.process(event), isNotNull);
    expect(coach.process(event), isNull);
  });

  test('form correction maps to visual demo', () {
    final coach = CoachEngine();
    final instruction = coach.process(
      const FormCorrectionEvent(
        exercise: ExerciseId.squat,
        timestampMs: 1000,
        error: FormError.kneesCollapsingInward,
        severity: 'warning',
      ),
    );
    expect(instruction?.visualDemoId, 'squat_knee_alignment_front');
    expect(instruction?.priority, greaterThan(50));
  });
}
