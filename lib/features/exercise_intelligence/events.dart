/// Versioned exercise intelligence events. Mirrors docs/INTERNAL_APIS.md.
library;

enum ExerciseId { squat, pushup, bicepCurl, lunge, shoulderPress, plank }

extension ExerciseIdX on ExerciseId {
  String get wireName => switch (this) {
        ExerciseId.squat => 'squat',
        ExerciseId.pushup => 'pushup',
        ExerciseId.bicepCurl => 'bicep_curl',
        ExerciseId.lunge => 'lunge',
        ExerciseId.shoulderPress => 'shoulder_press',
        ExerciseId.plank => 'plank',
      };
}

enum MovementPhase { ready, standing, descending, bottom, ascending, incomplete, resting }

extension MovementPhaseX on MovementPhase {
  String get wireName => switch (this) {
        MovementPhase.ready => 'ready',
        MovementPhase.standing => 'standing',
        MovementPhase.descending => 'descent',
        MovementPhase.bottom => 'bottom',
        MovementPhase.ascending => 'ascent',
        MovementPhase.incomplete => 'incomplete',
        MovementPhase.resting => 'resting',
      };
}

enum FormError {
  none,
  kneesCollapsingInward,
  hipSag,
  insufficientDepth,
  trunkLean,
  lowCameraConfidence,
  slowMovement,
  incorrectBodyAlignment,
}

extension FormErrorX on FormError {
  String get wireName => switch (this) {
        FormError.none => 'none',
        FormError.kneesCollapsingInward => 'knees_collapsing_inward',
        FormError.hipSag => 'hip_sag',
        FormError.insufficientDepth => 'insufficient_depth',
        FormError.trunkLean => 'trunk_lean',
        FormError.lowCameraConfidence => 'low_visibility',
        FormError.slowMovement => 'slow_movement',
        FormError.incorrectBodyAlignment => 'incorrect_body_alignment',
      };
}

sealed class ExerciseEvent {
  const ExerciseEvent({
    required this.exercise,
    required this.timestampMs,
    this.confidence = 1,
  });

  final ExerciseId exercise;
  final int timestampMs;
  final double confidence;

  String get eventName;

  Map<String, dynamic> toJson();
}

class RepCompletedEvent extends ExerciseEvent {
  const RepCompletedEvent({
    required super.exercise,
    required super.timestampMs,
    required this.repCount,
    required this.phase,
    super.confidence,
  });

  final int repCount;
  final MovementPhase phase;

  @override
  String get eventName => 'rep_completed';

  @override
  Map<String, dynamic> toJson() => {
        'event': eventName,
        'schema_version': 1,
        'exercise': exercise.wireName,
        'rep_count': repCount,
        'phase': phase.wireName,
        'confidence': confidence,
        'timestamp_ms': timestampMs,
      };
}

class FormCorrectionEvent extends ExerciseEvent {
  const FormCorrectionEvent({
    required super.exercise,
    required super.timestampMs,
    required this.error,
    required this.severity,
    super.confidence,
  });

  final FormError error;
  final String severity;

  @override
  String get eventName => 'form_correction';

  @override
  Map<String, dynamic> toJson() => {
        'event': eventName,
        'schema_version': 1,
        'exercise': exercise.wireName,
        'error_code': error.wireName,
        'severity': severity,
        'confidence': confidence,
        'timestamp_ms': timestampMs,
      };
}

class PhaseChangedEvent extends ExerciseEvent {
  const PhaseChangedEvent({
    required super.exercise,
    required super.timestampMs,
    required this.phase,
    super.confidence,
  });

  final MovementPhase phase;

  @override
  String get eventName => 'movement_phase';

  @override
  Map<String, dynamic> toJson() => {
        'event': eventName,
        'schema_version': 1,
        'exercise': exercise.wireName,
        'phase': phase.wireName,
        'confidence': confidence,
        'timestamp_ms': timestampMs,
      };
}

class VisualDemoRequiredEvent extends ExerciseEvent {
  const VisualDemoRequiredEvent({
    required super.exercise,
    required super.timestampMs,
    required this.demoId,
    required this.cameraView,
    super.confidence,
  });

  final String demoId;
  final String cameraView;

  @override
  String get eventName => 'visual_demo_required';

  @override
  Map<String, dynamic> toJson() => {
        'event': eventName,
        'schema_version': 1,
        'exercise': exercise.wireName,
        'demo_id': demoId,
        'camera_view': cameraView,
        'timestamp_ms': timestampMs,
      };
}
