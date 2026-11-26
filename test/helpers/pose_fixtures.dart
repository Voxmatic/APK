import 'dart:math' as math;

import 'package:ai_gym_trainer/features/exercise_intelligence/biomechanics.dart';

/// Builds a synthetic-but-geometrically-real 33-landmark frame for squat tests.
/// `depth`: 0 = standing (knee ~180°), 1 = bottom (knee ~107°).
PoseFrame squatFrame({required double depth, required int t, double kneeXOffset = 0}) {
  final lms = List<PoseLandmark>.generate(
    33,
    (_) => const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0.95, presence: 0.95),
  );
  final hipY = 0.40 + 0.28 * depth;
  final kneeY = 0.64 + 0.08 * depth;
  final kneeX = 0.50 - 0.10 * depth + kneeXOffset;
  lms[LandmarkIndex.leftHip] = PoseLandmark(x: 0.46, y: hipY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightHip] = PoseLandmark(x: 0.54, y: hipY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftKnee] = PoseLandmark(x: kneeX - 0.02, y: kneeY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightKnee] = PoseLandmark(x: kneeX + 0.02, y: kneeY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftAnkle] = const PoseLandmark(x: 0.46, y: 0.90, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightAnkle] = const PoseLandmark(x: 0.54, y: 0.90, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftShoulder] = PoseLandmark(x: 0.40, y: hipY - 0.28, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightShoulder] = PoseLandmark(x: 0.60, y: hipY - 0.28, z: 0, visibility: 0.95, presence: 0.95);
  return PoseFrame(landmarks: lms, timestampMs: t);
}

/// Push-up frame. `depth` 0 = arms extended (~170°), 1 = chest down (~85°).
PoseFrame pushupFrame({required double depth, required int t, double hipSag = 0}) {
  final lms = List<PoseLandmark>.generate(
    33,
    (_) => const PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0.95, presence: 0.95),
  );
  // Side-on: shoulder at x=0.35, elbow and wrist to the right.
  final shoulderX = 0.32;
  final shoulderY = 0.45;
  final elbowX = 0.40 + 0.05 * depth;
  final elbowY = 0.45 + 0.18 * depth;
  final wristX = 0.55;
  final wristY = 0.45;
  lms[LandmarkIndex.leftShoulder] = PoseLandmark(x: shoulderX, y: shoulderY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightShoulder] = PoseLandmark(x: shoulderX, y: shoulderY + 0.02, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftElbow] = PoseLandmark(x: elbowX, y: elbowY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightElbow] = PoseLandmark(x: elbowX, y: elbowY + 0.02, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftWrist] = PoseLandmark(x: wristX, y: wristY, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightWrist] = PoseLandmark(x: wristX, y: wristY + 0.02, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftHip] = PoseLandmark(x: 0.20, y: 0.45 + hipSag, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightHip] = PoseLandmark(x: 0.20, y: 0.47 + hipSag, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.leftAnkle] = const PoseLandmark(x: 0.05, y: 0.45, z: 0, visibility: 0.95, presence: 0.95);
  lms[LandmarkIndex.rightAnkle] = const PoseLandmark(x: 0.05, y: 0.47, z: 0, visibility: 0.95, presence: 0.95);
  return PoseFrame(landmarks: lms, timestampMs: t);
}

double elbowAngle(PoseFrame frame) {
  final a = frame.get(LandmarkIndex.leftShoulder)!;
  final b = frame.get(LandmarkIndex.leftElbow)!;
  final c = frame.get(LandmarkIndex.leftWrist)!;
  final v1x = a.x - b.x, v1y = a.y - b.y;
  final v2x = c.x - b.x, v2y = c.y - b.y;
  final cos = (v1x * v2x + v1y * v2y) /
      (math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y));
  return math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi;
}
