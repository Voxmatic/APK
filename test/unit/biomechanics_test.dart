import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/biomechanics.dart';

void main() {
  group('Biomechanics', () {
    test('joint angle for perpendicular segments is 90 degrees', () {
      const a = PoseLandmark(x: 0, y: 0, z: 0);
      const b = PoseLandmark(x: 0.5, y: 0.5, z: 0);
      const c = PoseLandmark(x: 1, y: 0, z: 0);
      final angle = Biomechanics.jointAngle(a, b, c);
      expect(angle, closeTo(90, 0.001));
    });

    test('straight line gives 180 degrees', () {
      const a = PoseLandmark(x: 0, y: 0.5, z: 0);
      const b = PoseLandmark(x: 0.5, y: 0.5, z: 0);
      const c = PoseLandmark(x: 1, y: 0.5, z: 0);
      expect(Biomechanics.jointAngle(a, b, c), closeTo(180, 0.001));
    });

    test('missing landmark returns NaN', () {
      const b = PoseLandmark(x: 0.5, y: 0.5, z: 0);
      expect(Biomechanics.jointAngle(null, b, b).isNaN, isTrue);
    });

    test('visibility averages supplied indices', () {
      final landmarks = List<PoseLandmark>.generate(
        33,
        (_) => const PoseLandmark(x: 0, y: 0, z: 0, visibility: 1, presence: 1),
      );
      final frame = PoseFrame(landmarks: landmarks, timestampMs: 0);
      expect(Biomechanics.visibility(frame, [0, 1, 2]), closeTo(1, 0.001));
    });
  });
}
