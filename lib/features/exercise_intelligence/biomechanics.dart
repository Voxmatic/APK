/// Pure-Dart biomechanics helpers. No Flutter imports: usable in unit tests and ML tooling.
library;

import 'dart:math' as math;

/// MediaPipe Pose landmark indices (33-point topology).
abstract final class LandmarkIndex {
  static const int nose = 0;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
}

class PoseLandmark {
  const PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 0,
    this.presence = 0,
  });

  final double x;
  final double y;
  final double z;
  final double visibility;
  final double presence;

  factory PoseLandmark.fromJson(Map<String, dynamic> json) => PoseLandmark(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    z: (json['z'] as num?)?.toDouble() ?? 0,
    visibility: (json['visibility'] as num?)?.toDouble() ?? 0,
    presence: (json['presence'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
    'visibility': visibility,
    'presence': presence,
  };
}

class PoseFrame {
  const PoseFrame({
    required this.landmarks,
    required this.timestampMs,
    this.worldLandmarks = const [],
    this.inferenceMs = 0,
    this.error = '',
  });

  final List<PoseLandmark> landmarks;
  final List<PoseLandmark> worldLandmarks;
  final int timestampMs;
  final double inferenceMs;
  final String error;

  bool get hasFullBody => landmarks.length == 33 && error.isEmpty;

  PoseLandmark? get(int index) =>
      index >= 0 && index < landmarks.length ? landmarks[index] : null;

  static PoseFrame fromJson(Map<String, dynamic> json) {
    final landmarks = <PoseLandmark>[];
    for (final value in (json['landmarks'] as List?) ?? const []) {
      landmarks.add(PoseLandmark.fromJson(value as Map<String, dynamic>));
    }
    final world = <PoseLandmark>[];
    for (final value in (json['worldLandmarks'] as List?) ?? const []) {
      world.add(PoseLandmark.fromJson(value as Map<String, dynamic>));
    }
    return PoseFrame(
      landmarks: landmarks,
      worldLandmarks: world,
      timestampMs: (json['timestamp_ms'] as num?)?.toInt() ?? 0,
      inferenceMs: (json['inference_ms'] as num?)?.toDouble() ?? 0,
      error: json['error'] as String? ?? '',
    );
  }
}

/// Geometry utilities. All coordinates are normalized image coordinates (0..1).
abstract final class Biomechanics {
  /// Interior angle at [b] formed by a-b-c, in degrees [0, 180].
  static double jointAngle(PoseLandmark? a, PoseLandmark? b, PoseLandmark? c) {
    if (a == null || b == null || c == null) return double.nan;
    final dx1 = a.x - b.x;
    final dy1 = a.y - b.y;
    final dx2 = c.x - b.x;
    final dy2 = c.y - b.y;
    final denom = math.sqrt((dx1 * dx1 + dy1 * dy1) * (dx2 * dx2 + dy2 * dy2));
    if (denom < 1e-9) return double.nan;
    final cos = ((dx1 * dx2 + dy1 * dy2) / denom).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  static double distance2d(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static PoseLandmark? midpoint(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) return null;
    return PoseLandmark(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      visibility: math.min(a.visibility, b.visibility),
    );
  }

  /// Mean visibility of the supplied indices. Missing landmarks count as zero.
  static double visibility(PoseFrame frame, List<int> indices) {
    if (indices.isEmpty) return 0;
    var total = 0.0;
    for (final i in indices) {
      final lm = frame.get(i);
      total += lm == null
          ? 0
          : math.min(lm.visibility, lm.presence == 0 ? 1.0 : lm.presence);
    }
    return total / indices.length;
  }

  /// Angle of the trunk away from vertical, degrees. 0 = perfectly upright.
  static double trunkTilt(PoseFrame frame) {
    final hip = midpoint(
      frame.get(LandmarkIndex.leftHip),
      frame.get(LandmarkIndex.rightHip),
    );
    final shoulder = midpoint(
      frame.get(LandmarkIndex.leftShoulder),
      frame.get(LandmarkIndex.rightShoulder),
    );
    if (hip == null || shoulder == null) return double.nan;
    final dx = shoulder.x - hip.x;
    final dy = shoulder.y - hip.y;
    return math.atan2(dx.abs(), dy.abs()) * 180 / math.pi;
  }

  /// Perpendicular distance of [point] from the line a->b, normalized units.
  static double pointToLineDistance(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark point,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-9) return 0;
    return ((point.x - a.x) * dy - (point.y - a.y) * dx).abs() / length;
  }

  /// Signed deviation of the knee from the hip->ankle line (positive = outward).
  static double kneeAlignment(PoseFrame frame, bool left) {
    final hip = frame.get(
      left ? LandmarkIndex.leftHip : LandmarkIndex.rightHip,
    );
    final knee = frame.get(
      left ? LandmarkIndex.leftKnee : LandmarkIndex.rightKnee,
    );
    final ankle = frame.get(
      left ? LandmarkIndex.leftAnkle : LandmarkIndex.rightAnkle,
    );
    if (hip == null || knee == null || ankle == null) return double.nan;
    final dx = ankle.x - hip.x;
    final dy = ankle.y - hip.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-9) return 0;
    final cross = (knee.x - hip.x) * dy - (knee.y - hip.y) * dx;
    final shoulderWidth = Biomechanics.distance2d(
      frame.get(LandmarkIndex.leftShoulder) ?? hip,
      frame.get(LandmarkIndex.rightShoulder) ?? hip,
    );
    return cross / length / math.max(shoulderWidth, 0.05);
  }
}
