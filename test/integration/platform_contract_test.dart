import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/biomechanics.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/events.dart';

void main() {
  test('pose frame JSON contract parses compact native event', () {
    final json = {
      'event': 'pose_frame',
      'schema_version': 1,
      'timestamp_ms': 12345,
      'landmarks': List.generate(
        33,
        (i) => {
          'x': 0.5,
          'y': 0.5,
          'z': 0.0,
          'visibility': 0.9,
          'presence': 0.9,
        },
      ),
      'worldLandmarks': List.generate(
        33,
        (i) => {'x': 0.0, 'y': 0.0, 'z': 0.0},
      ),
      'inference_ms': 12.3,
    };
    final frame = PoseFrame.fromJson(json);
    expect(frame.landmarks.length, 33);
    expect(frame.timestampMs, 12345);
    expect(frame.inferenceMs, closeTo(12.3, 0.001));
    expect(frame.hasFullBody, isTrue);
  });

  test('rep event JSON uses versioned schema', () {
    final event = RepCompletedEvent(
      exercise: ExerciseId.squat,
      timestampMs: 42,
      repCount: 7,
      phase: MovementPhase.standing,
      confidence: 0.95,
    );
    final encoded = jsonEncode(event.toJson());
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['schema_version'], 1);
    expect(decoded['event'], 'rep_completed');
    expect(decoded['exercise'], 'squat');
    expect(decoded['rep_count'], 7);
  });

  test('form correction event serializes error code', () {
    final event = FormCorrectionEvent(
      exercise: ExerciseId.pushup,
      timestampMs: 10,
      error: FormError.hipSag,
      severity: 'warning',
    );
    expect(event.toJson()['error_code'], 'hip_sag');
  });
}
