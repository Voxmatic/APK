/// Deterministic coaching policy. Safety rules always win; the optional LLM
/// can only vary phrasing, never override a rep, angle or safety decision.
library;

import '../exercise_intelligence/events.dart';

class CoachInstruction {
  const CoachInstruction({
    required this.id,
    required this.phraseKey,
    required this.priority,
    this.visualDemoId,
    this.stopWorkout = false,
  });

  final String id;
  final String phraseKey;
  final int priority;
  final String? visualDemoId;
  final bool stopWorkout;
}

class CoachEngine {
  CoachEngine({this.cooldownMs = 2600});

  final int cooldownMs;
  final Map<String, int> _lastEmittedAt = {};
  CoachInstruction? _current;

  CoachInstruction? get current => _current;

  /// Process an exercise event and return an instruction when one should be spoken.
  CoachInstruction? process(ExerciseEvent event, {bool userReportedPain = false}) {
    if (userReportedPain) {
      return _emit(const CoachInstruction(
        id: 'pain_stop',
        phraseKey: 'pain_stop',
        priority: 100,
        stopWorkout: true,
      ), event.timestampMs, force: true);
    }

    if (event is FormCorrectionEvent) {
      final instruction = _forFormError(event);
      if (instruction != null) return _emit(instruction, event.timestampMs);
    }

    if (event is RepCompletedEvent) {
      if (event.repCount % 5 == 0 && event.repCount > 0) {
        return _emit(const CoachInstruction(
          id: 'excellent',
          phraseKey: 'excellent',
          priority: 15,
        ), event.timestampMs);
      }
      return _emit(const CoachInstruction(
        id: 'good_rep',
        phraseKey: 'good_rep',
        priority: 10,
      ), event.timestampMs);
    }

    if (event is VisualDemoRequiredEvent) {
      return _emit(CoachInstruction(
        id: 'show_demo',
        phraseKey: 'show_demo',
        priority: 45,
        visualDemoId: event.demoId,
      ), event.timestampMs);
    }

    return null;
  }

  CoachInstruction? _forFormError(FormCorrectionEvent event) {
    switch (event.error) {
      case FormError.kneesCollapsingInward:
        return const CoachInstruction(
          id: 'knee_alignment',
          phraseKey: 'knees_collapsing_inward',
          priority: 70,
          visualDemoId: 'squat_knee_alignment_front',
        );
      case FormError.hipSag:
        return const CoachInstruction(
          id: 'hip_sag',
          phraseKey: 'hip_sag',
          priority: 75,
          visualDemoId: 'pushup_hip_alignment_side',
        );
      case FormError.insufficientDepth:
        return const CoachInstruction(
          id: 'go_deeper',
          phraseKey: 'insufficient_depth',
          priority: 65,
          visualDemoId: 'squat_depth_front',
        );
      case FormError.trunkLean:
        return const CoachInstruction(
          id: 'trunk_lean',
          phraseKey: 'trunk_lean',
          priority: 60,
        );
      case FormError.lowCameraConfidence:
        return const CoachInstruction(
          id: 'camera_hint',
          phraseKey: 'low_visibility',
          priority: 40,
        );
      case FormError.slowMovement:
        return const CoachInstruction(
          id: 'control_movement',
          phraseKey: 'slow_movement',
          priority: 50,
        );
      case FormError.incorrectBodyAlignment:
        return const CoachInstruction(
          id: 'body_alignment',
          phraseKey: 'incorrect_body_alignment',
          priority: 55,
        );
      case FormError.none:
        return null;
    }
  }

  CoachInstruction? _emit(CoachInstruction instruction, int timestamp, {bool force = false}) {
    final last = _lastEmittedAt[instruction.id];
    if (!force && last != null && timestamp - last < cooldownMs) return null;
    _lastEmittedAt[instruction.id] = timestamp;
    _current = instruction;
    return instruction;
  }

  void reset() {
    _lastEmittedAt.clear();
    _current = null;
  }
}
