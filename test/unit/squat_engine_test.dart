import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/events.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/squat_engine.dart';

import '../helpers/pose_fixtures.dart';

void main() {
  test('full descent-bottom-ascent produces exactly one rep', () {
    final engine = SquatEngine();
    final sequence = <double>[0, 0.7, 1.0, 0.7, 0];
    final all = <ExerciseEvent>[];
    for (var i = 0; i < sequence.length; i++) {
      all.addAll(engine.update(squatFrame(depth: sequence[i], t: i * 100)));
    }
    final reps = all.whereType<RepCompletedEvent>().toList();
    expect(reps.length, 1);
    expect(reps.first.repCount, 1);
    expect(engine.phase, MovementPhase.standing);
  });

  test('shallow movement never increments the counter', () {
    final engine = SquatEngine();
    final all = <ExerciseEvent>[];
    for (var i = 0; i < 6; i++) {
      all.addAll(
        engine.update(squatFrame(depth: i.isEven ? 0 : 0.2, t: i * 100)),
      );
    }
    expect(all.whereType<RepCompletedEvent>(), isEmpty);
    expect(engine.repCount, 0);
  });

  test('multiple full reps count sequentially', () {
    final engine = SquatEngine();
    for (var rep = 0; rep < 3; rep++) {
      for (final depth in [0.0, 0.7, 1.0, 0.7, 0.0]) {
        engine.update(
          squatFrame(depth: depth, t: rep * 500 + (depth * 100).round()),
        );
      }
    }
    expect(engine.repCount, 3);
  });
}
