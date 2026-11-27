/// Deterministic push-up state machine with plank alignment and hip-sag checks.
/// A repetition is only emitted after descent -> bottom -> ascent -> top.
library;

import 'dart:math' as math;

import 'biomechanics.dart';
import 'events.dart';

class PushUpEngine {
  static const _required = <int>[
    LandmarkIndex.leftShoulder,
    LandmarkIndex.rightShoulder,
    LandmarkIndex.leftElbow,
    LandmarkIndex.rightElbow,
    LandmarkIndex.leftWrist,
    LandmarkIndex.rightWrist,
    LandmarkIndex.leftHip,
    LandmarkIndex.rightHip,
    LandmarkIndex.leftAnkle,
    LandmarkIndex.rightAnkle,
  ];

  MovementPhase phase = MovementPhase.ready;
  int repCount = 0;
  double lastElbowAngle = double.nan;
  double confidence = 0;

  bool _inPlank = false;
  bool _sawDescent = false;
  bool _reachedBottom = false;
  double _minAngle = 180;
  int? _lastTimestamp;
  int? _stallSince;
  final Map<FormError, int> _lastErrorAt = {};

  List<ExerciseEvent> update(PoseFrame frame) {
    final events = <ExerciseEvent>[];
    final visibility = Biomechanics.visibility(frame, _required);
    confidence = visibility;
    if (visibility < 0.5) {
      _emitOnce(
        FormError.lowCameraConfidence,
        frame.timestampMs,
        visibility,
        events,
      );
      return events;
    }

    final left = Biomechanics.jointAngle(
      frame.get(LandmarkIndex.leftShoulder),
      frame.get(LandmarkIndex.leftElbow),
      frame.get(LandmarkIndex.leftWrist),
    );
    final right = Biomechanics.jointAngle(
      frame.get(LandmarkIndex.rightShoulder),
      frame.get(LandmarkIndex.rightElbow),
      frame.get(LandmarkIndex.rightWrist),
    );
    final angle = _average(left, right);
    final shoulder = Biomechanics.midpoint(
      frame.get(LandmarkIndex.leftShoulder),
      frame.get(LandmarkIndex.rightShoulder),
    );
    final hip = Biomechanics.midpoint(
      frame.get(LandmarkIndex.leftHip),
      frame.get(LandmarkIndex.rightHip),
    );
    final ankle = Biomechanics.midpoint(
      frame.get(LandmarkIndex.leftAnkle),
      frame.get(LandmarkIndex.rightAnkle),
    );
    if (angle.isNaN || shoulder == null || hip == null || ankle == null) {
      _emitOnce(
        FormError.lowCameraConfidence,
        frame.timestampMs,
        visibility,
        events,
      );
      return events;
    }

    // Body must be approximately horizontal before a rep can be accepted.
    final bodyTilt = (shoulder.y - ankle.y).abs();
    if (bodyTilt > 0.24) {
      _emitOnce(
        FormError.incorrectBodyAlignment,
        frame.timestampMs,
        visibility,
        events,
      );
      _resetSequence();
      return events;
    }
    _inPlank = true;

    final sag = _signedVerticalDeviation(shoulder, ankle, hip);
    if (sag > 0.075) {
      _emitOnce(FormError.hipSag, frame.timestampMs, visibility, events);
    }

    final timestamp = frame.timestampMs;
    final dt = _lastTimestamp == null ? 0 : timestamp - _lastTimestamp!;
    _lastTimestamp = timestamp;
    if (_sawDescent && angle < _minAngle) _minAngle = angle;
    final previous = lastElbowAngle;
    lastElbowAngle = angle;

    if (_inPlank && angle >= 155) {
      if (_sawDescent && _reachedBottom) {
        repCount++;
        events.add(
          RepCompletedEvent(
            exercise: ExerciseId.pushup,
            timestampMs: timestamp,
            repCount: repCount,
            phase: MovementPhase.standing,
            confidence: math.min(visibility, 0.98),
          ),
        );
        _resetSequence();
      } else if (_sawDescent) {
        _emitOnce(FormError.insufficientDepth, timestamp, visibility, events);
        _resetSequence();
      }
      _setPhase(MovementPhase.standing, timestamp, visibility, events);
    } else if (angle <= 140 &&
        (!_sawDescent || previous.isNaN || previous >= 150)) {
      _sawDescent = true;
      _minAngle = angle;
      _setPhase(MovementPhase.descending, timestamp, visibility, events);
    }

    if (angle <= 95) {
      _reachedBottom = true;
      _minAngle = math.min(_minAngle, angle);
      _setPhase(MovementPhase.bottom, timestamp, visibility, events);
    } else if (_reachedBottom && _sawDescent && angle > _minAngle + 12) {
      _setPhase(MovementPhase.ascending, timestamp, visibility, events);
    }

    if (dt > 0 &&
        !previous.isNaN &&
        (angle - previous).abs() / (dt / 1000) < 6) {
      _stallSince ??= timestamp;
      if (timestamp - _stallSince! > 1200 && phase != MovementPhase.standing) {
        _emitOnce(FormError.slowMovement, timestamp, visibility, events);
      }
    } else {
      _stallSince = null;
    }
    return events;
  }

  /// Positive when [point] is lower on screen than the shoulder->ankle line.
  static double _signedVerticalDeviation(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark point,
  ) {
    final t =
        ((point.x - a.x) * (b.x - a.x) + (point.y - a.y) * (b.y - a.y)) /
        math.max((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y), 1e-9);
    final lineY = a.y + (b.y - a.y) * t.clamp(0.0, 1.0);
    return point.y - lineY;
  }

  void _setPhase(
    MovementPhase next,
    int timestamp,
    double visibility,
    List<ExerciseEvent> events,
  ) {
    if (phase == next) return;
    phase = next;
    events.add(
      PhaseChangedEvent(
        exercise: ExerciseId.pushup,
        timestampMs: timestamp,
        phase: next,
        confidence: visibility,
      ),
    );
  }

  void _emitOnce(
    FormError error,
    int timestamp,
    double visibility,
    List<ExerciseEvent> events,
  ) {
    final last = _lastErrorAt[error];
    if (last != null && timestamp - last < 2500) return;
    _lastErrorAt[error] = timestamp;
    events.add(
      FormCorrectionEvent(
        exercise: ExerciseId.pushup,
        timestampMs: timestamp,
        error: error,
        severity: error == FormError.lowCameraConfidence ? 'info' : 'warning',
        confidence: visibility,
      ),
    );
  }

  void _resetSequence() {
    _inPlank = false;
    _sawDescent = false;
    _reachedBottom = false;
    _minAngle = 180;
    _stallSince = null;
  }

  /// Starts a new set without discarding accumulated session state.
  void resetForNextSet() {
    repCount = 0;
    _resetSequence();
    lastElbowAngle = double.nan;
    _lastTimestamp = null;
    _setPhase(
      MovementPhase.standing,
      DateTime.now().millisecondsSinceEpoch,
      confidence,
      [],
    );
  }

  static double _average(double a, double b) {
    if (a.isNaN) return b;
    if (b.isNaN) return a;
    return (a + b) / 2;
  }
}
