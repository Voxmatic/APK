import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/biomechanics.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/events.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/pushup_engine.dart';

import '../helpers/pose_fixtures.dart';

void main() {
  test('full push-up rep counts once', () {
    final engine = PushUpEngine();
    final all = <ExerciseEvent>[];
    final sequence = [0.0, 0.5, 1.0, 0.5, 0.0];
    for (var i = 0; i < sequence.length; i++) {
      all.addAll(engine.update(pushupFrame(depth: sequence[i], t: i * 100)));
    }
    final reps = all.whereType<RepCompletedEvent>().toList();
    expect(reps.length, 1);
    expect(reps.first.repCount, 1);
  });

  test('hip sag produces a form correction', () {
    final engine = PushUpEngine();
    final all = <ExerciseEvent>[];
    for (var i = 0; i < 4; i++) {
      all.addAll(
        engine.update(pushupFrame(depth: 0.5, t: i * 100, hipSag: 0.12)),
      );
    }
    final errors = all
        .whereType<FormCorrectionEvent>()
        .map((e) => e.error)
        .toSet();
    expect(errors.contains(FormError.hipSag), isTrue);
  });

  test('upright body is rejected as incorrect alignment', () {
    final engine = PushUpEngine();
    final frame = pushupFrame(depth: 0.5, t: 0);
    // Force the ankle far below the shoulders so |shoulder.y - ankle.y| > 0.24.
    final lms = List<PoseLandmark>.from(frame.landmarks);
    for (final idx in [27, 28]) {
      final lm = lms[idx];
      lms[idx] = PoseLandmark(
        x: lm.x,
        y: 0.85,
        z: 0,
        visibility: 0.95,
        presence: 0.95,
      );
    }
    final events = engine.update(PoseFrame(landmarks: lms, timestampMs: 0));
    expect(
      events.whereType<FormCorrectionEvent>().any(
        (e) => e.error == FormError.incorrectBodyAlignment,
      ),
      isTrue,
    );
    expect(engine.repCount, 0);
  });
}
