/// Deterministic squat state machine. A repetition requires a complete
/// READY -> STANDING -> DESCENDING -> BOTTOM -> ASCENDING -> STANDING sequence.
/// No LLM and no single threshold crossing can increment the counter.
library;

import 'dart:math' as math;

import 'biomechanics.dart';
import 'events.dart';

class SquatEngine {
  SquatEngine({this.targetReps = 10});

  static const _required = <int>[
    LandmarkIndex.leftHip, LandmarkIndex.rightHip,
    LandmarkIndex.leftKnee, LandmarkIndex.rightKnee,
    LandmarkIndex.leftAnkle, LandmarkIndex.rightAnkle,
    LandmarkIndex.leftShoulder, LandmarkIndex.rightShoulder,
  ];

  final int targetReps;
  MovementPhase phase = MovementPhase.ready;
  int repCount = 0;
  double lastKneeAngle = double.nan;
  double confidence = 0;

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
      _emitOnce(FormError.lowCameraConfidence, frame.timestampMs, visibility, events);
      return events;
    }

    final left = Biomechanics.jointAngle(
      frame.get(LandmarkIndex.leftHip),
      frame.get(LandmarkIndex.leftKnee),
      frame.get(LandmarkIndex.leftAnkle),
    );
    final right = Biomechanics.jointAngle(
      frame.get(LandmarkIndex.rightHip),
      frame.get(LandmarkIndex.rightKnee),
      frame.get(LandmarkIndex.rightAnkle),
    );
    final angle = _average(left, right);
    if (angle.isNaN) {
      _emitOnce(FormError.lowCameraConfidence, frame.timestampMs, visibility, events);
      return events;
    }

    _checkForm(frame, angle, visibility, events);

    final timestamp = frame.timestampMs;
    final dt = _lastTimestamp == null ? 0 : timestamp - _lastTimestamp!;
    _lastTimestamp = timestamp;

    if (_sawDescent && angle < _minAngle) _minAngle = angle;
    final previous = lastKneeAngle;
    lastKneeAngle = angle;

    if (angle >= 158) {
      if (_sawDescent && _reachedBottom) {
        repCount++;
        events.add(RepCompletedEvent(
          exercise: ExerciseId.squat,
          timestampMs: timestamp,
          repCount: repCount,
          phase: MovementPhase.standing,
          confidence: math.min(visibility, 0.98),
        ));
        _resetSequence();
      } else if (_sawDescent) {
        _emitOnce(FormError.insufficientDepth, timestamp, visibility, events);
        _resetSequence();
      }
      _setPhase(MovementPhase.standing, timestamp, visibility, events);
    } else if (angle <= 150 && (!_sawDescent || previous.isNaN || previous >= 152)) {
      _sawDescent = true;
      _minAngle = angle;
      _setPhase(MovementPhase.descending, timestamp, visibility, events);
    }

    if (angle <= 108) {
      _reachedBottom = true;
      _minAngle = math.min(_minAngle, angle);
      _setPhase(MovementPhase.bottom, timestamp, visibility, events);
    } else if (_reachedBottom && _sawDescent && angle > _minAngle + 12) {
      _setPhase(MovementPhase.ascending, timestamp, visibility, events);
    }

    if (dt > 0 && !previous.isNaN && (angle - previous).abs() / (dt / 1000) < 6) {
      _stallSince ??= timestamp;
      if (timestamp - _stallSince! > 1200 && phase != MovementPhase.standing) {
        _emitOnce(FormError.slowMovement, timestamp, visibility, events);
      }
    } else {
      _stallSince = null;
    }
    return events;
  }

  void _checkForm(
    PoseFrame frame,
    double angle,
    double visibility,
    List<ExerciseEvent> events,
  ) {
    if (phase == MovementPhase.descending || phase == MovementPhase.bottom) {
      final left = Biomechanics.kneeAlignment(frame, true);
      final right = Biomechanics.kneeAlignment(frame, false);
      final collapsed = (!left.isNaN && left < -0.32) || (!right.isNaN && right < -0.32);
      if (collapsed) {
        _emitOnce(FormError.kneesCollapsingInward, frame.timestampMs, visibility, events);
      }
      final tilt = Biomechanics.trunkTilt(frame);
      if (!tilt.isNaN && tilt > 34) {
        _emitOnce(FormError.trunkLean, frame.timestampMs, visibility, events);
      }
    }
  }

  void _setPhase(
    MovementPhase next,
    int timestamp,
    double visibility,
    List<ExerciseEvent> events,
  ) {
    if (phase == next) return;
    phase = next;
    events.add(PhaseChangedEvent(
      exercise: ExerciseId.squat,
      timestampMs: timestamp,
      phase: next,
      confidence: visibility,
    ));
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
    events.add(FormCorrectionEvent(
      exercise: ExerciseId.squat,
      timestampMs: timestamp,
      error: error,
      severity: error == FormError.lowCameraConfidence ? 'info' : 'warning',
      confidence: visibility,
    ));
  }

  void _resetSequence() {
    _sawDescent = false;
    _reachedBottom = false;
    _minAngle = 180;
    _stallSince = null;
  }

  static double _average(double a, double b) {
    if (a.isNaN) return b;
    if (b.isNaN) return a;
    return (a + b) / 2;
  }
}
