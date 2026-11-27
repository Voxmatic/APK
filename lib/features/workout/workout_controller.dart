/// Workout session state machine driven by real pose frames.
/// All counting is deterministic; no event is fabricated for the UI and no
/// native failure is allowed to escape as an uncaught exception.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/platform/camera_session.dart';
import '../../core/platform/pose_channel.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/workout_db.dart';
import '../../domain/workout_plan.dart';
import '../coach/coach_engine.dart';
import '../exercise_intelligence/biomechanics.dart';
import '../exercise_intelligence/events.dart';
import '../exercise_intelligence/pushup_engine.dart';
import '../exercise_intelligence/squat_engine.dart';
import '../voice/voice_service.dart';

final platformBridgeProvider = Provider<PlatformBridge>(
  (ref) => PlatformBridge(),
);

final poseStreamProvider = StreamProvider<PoseFrame>((ref) {
  ref.keepAlive();
  return ref.watch(platformBridgeProvider).poseStream();
});

final systemEventsProvider = StreamProvider<SystemEvent>((ref) {
  ref.keepAlive();
  return ref.watch(platformBridgeProvider).systemStream();
});

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
final workoutDatabaseProvider = Provider<WorkoutStore>(
  (ref) => WorkoutDatabase(),
);
final settingsProvider = Provider<AppLanguage>(
  (ref) => ref.watch(settingsControllerProvider).language,
);

class WorkoutState {
  const WorkoutState({
    this.exercise,
    this.running = false,
    this.paused = false,
    this.reps = 0,
    this.setReps = 0,
    this.setsCompleted = 0,
    this.targetReps = 10,
    this.targetSets = 3,
    this.phase = MovementPhase.ready,
    this.confidence = 0,
    this.instruction,
    this.demoId,
    this.formEvents = const [],
    this.cameraError = '',
    this.poseError = '',
    this.runtime,
    this.startedAtMs = 0,
    this.endedAtMs = 0,
    this.durationMs = 0,
    this.restUntilMs = 0,
    this.planId = '',
  });

  final ExerciseId? exercise;
  final bool running;
  final bool paused;
  final int reps;
  final int setReps;
  final int setsCompleted;
  final int targetReps;
  final int targetSets;
  final MovementPhase phase;
  final double confidence;
  final String? instruction;
  final String? demoId;
  final List<FormCorrectionEvent> formEvents;
  final String cameraError;
  final String poseError;
  final PoseRuntimeStatus? runtime;
  final int startedAtMs;
  final int endedAtMs;
  final int durationMs;
  final int restUntilMs;
  final String planId;

  bool get isResting => restUntilMs > DateTime.now().millisecondsSinceEpoch;
  bool get isFinished => endedAtMs > 0;

  WorkoutState copyWith({
    ExerciseId? exercise,
    bool? running,
    bool? paused,
    int? reps,
    int? setReps,
    int? setsCompleted,
    int? targetReps,
    int? targetSets,
    MovementPhase? phase,
    double? confidence,
    String? instruction,
    bool clearInstruction = false,
    String? demoId,
    bool clearDemo = false,
    List<FormCorrectionEvent>? formEvents,
    String? cameraError,
    String? poseError,
    PoseRuntimeStatus? runtime,
    int? startedAtMs,
    int? endedAtMs,
    int? durationMs,
    int? restUntilMs,
    String? planId,
  }) => WorkoutState(
    exercise: exercise ?? this.exercise,
    running: running ?? this.running,
    paused: paused ?? this.paused,
    reps: reps ?? this.reps,
    setReps: setReps ?? this.setReps,
    setsCompleted: setsCompleted ?? this.setsCompleted,
    targetReps: targetReps ?? this.targetReps,
    targetSets: targetSets ?? this.targetSets,
    phase: phase ?? this.phase,
    confidence: confidence ?? this.confidence,
    instruction: clearInstruction ? null : instruction ?? this.instruction,
    demoId: clearDemo ? null : demoId ?? this.demoId,
    formEvents: formEvents ?? this.formEvents,
    cameraError: cameraError ?? this.cameraError,
    poseError: poseError ?? this.poseError,
    runtime: runtime ?? this.runtime,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs ?? this.endedAtMs,
    durationMs: durationMs ?? this.durationMs,
    restUntilMs: restUntilMs ?? this.restUntilMs,
    planId: planId ?? this.planId,
  );
}

class WorkoutController extends Notifier<WorkoutState> {
  SquatEngine? _squat;
  PushUpEngine? _pushup;
  final CoachEngine _coach = CoachEngine();
  final List<FormCorrectionEvent> _formEvents = [];
  int _sessionReps = 0;

  @override
  WorkoutState build() {
    ref.onDispose(() {
      _squat = null;
      _pushup = null;
    });
    return const WorkoutState();
  }

  void start(
    ExerciseId exercise, {
    int targetReps = 10,
    int targetSets = 3,
    String planId = '',
  }) {
    _squat = exercise == ExerciseId.squat
        ? SquatEngine(targetReps: targetReps)
        : null;
    _pushup = exercise == ExerciseId.pushup ? PushUpEngine() : null;
    _coach.reset();
    _formEvents.clear();
    _sessionReps = 0;
    state = WorkoutState(
      exercise: exercise,
      running: true,
      targetReps: targetReps,
      targetSets: targetSets,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
      planId: planId,
    );
  }

  void startFromPlan(WorkoutPlan plan, ExerciseId exercise) {
    final entry = plan.entries.firstWhere(
      (e) => e.exercise == exercise,
      orElse: () => plan.first,
    );
    start(
      exercise,
      targetReps: entry.targetReps,
      targetSets: entry.targetSets,
      planId: plan.id,
    );
  }

  /// Camera start is explicit and awaited so failures reach the UI instead of
  /// escaping from a fire-and-forget Future.
  Future<bool> beginCamera() async {
    final result = await ref.read(cameraSessionProvider).start();
    if (!result.ok) {
      state = state.copyWith(
        cameraError: result.message ?? 'Camera could not start',
        running: result.code == 'PERMISSION_PENDING' ? state.running : false,
      );
      return false;
    }
    final status = await ref.read(platformBridgeProvider).poseStatus();
    state = state.copyWith(
      cameraError: '',
      poseError: status.lastError,
      runtime: status,
    );
    return true;
  }

  Future<void> endCamera() async {
    final result = await ref.read(cameraSessionProvider).stop();
    if (!result.ok) {
      state = state.copyWith(
        cameraError: result.message ?? 'Camera stop failed',
      );
    }
  }

  Future<void> releaseModel() => ref.read(platformBridgeProvider).unloadModel();

  void pause() => state = state.copyWith(running: false, paused: true);

  void resume() =>
      state = state.copyWith(running: true, paused: false, restUntilMs: 0);

  void stop() {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(
      running: false,
      paused: false,
      endedAtMs: now,
      durationMs: state.startedAtMs == 0 ? 0 : now - state.startedAtMs,
      restUntilMs: 0,
    );
  }

  void clearInstruction() =>
      state = state.copyWith(clearInstruction: true, clearDemo: true);

  void syncLanguage(AppLanguage language) {
    ref.read(voiceServiceProvider).setLanguage(language);
    ref.read(settingsControllerProvider.notifier).setLanguage(language);
  }

  /// Deterministic pain rule. The voice service may speak the approved phrase;
  /// the stop decision never depends on a model.
  Future<void> reportPain() async {
    final instruction = _coach.process(
      FormCorrectionEvent(
        exercise: state.exercise ?? ExerciseId.squat,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        error: FormError.none,
        severity: 'stop',
      ),
      userReportedPain: true,
    );
    if (instruction != null) {
      await ref.read(voiceServiceProvider).speak(instruction);
    }
    stop();
  }

  /// Feed one real pose frame from the native EventChannel.
  void onPoseFrame(PoseFrame frame) {
    final current = state;
    if (frame.error.isNotEmpty) {
      state = current.copyWith(poseError: frame.error);
      return;
    }
    if (!current.running ||
        current.paused ||
        current.exercise == null ||
        current.isResting)
      return;

    final events = switch (current.exercise!) {
      ExerciseId.squat => _squat?.update(frame) ?? const <ExerciseEvent>[],
      ExerciseId.pushup => _pushup?.update(frame) ?? const <ExerciseEvent>[],
      _ => const <ExerciseEvent>[],
    };
    if (events.isEmpty) return;

    String? instructionKey;
    String? demoId;
    final voice = ref.read(voiceServiceProvider);
    var setCompleted = false;
    for (final event in events) {
      if (event is FormCorrectionEvent) _formEvents.add(event);
      if (event is RepCompletedEvent) {
        _sessionReps++;
        if (_sessionReps % current.targetReps == 0) {
          setCompleted = true;
        }
      }
      final coachInstruction = _coach.process(event);
      if (coachInstruction != null) {
        instructionKey = coachInstruction.phraseKey;
        demoId = coachInstruction.visualDemoId;
        voice.speak(coachInstruction);
      }
    }

    if (setCompleted) {
      final completedSets = current.setsCompleted + 1;
      final finished = completedSets >= current.targetSets;
      final restUntil = DateTime.now().millisecondsSinceEpoch + 45_000;
      const setInstruction = CoachInstruction(
        id: 'set_complete',
        phraseKey: 'set_complete',
        priority: 90,
      );
      voice.speak(setInstruction);
      instructionKey = setInstruction.phraseKey;
      state = current.copyWith(
        reps: _sessionReps,
        setReps: current.targetReps,
        setsCompleted: completedSets,
        phase: _squat?.phase ?? _pushup?.phase ?? current.phase,
        confidence:
            _squat?.confidence ?? _pushup?.confidence ?? current.confidence,
        instruction: instructionKey,
        demoId: demoId,
        formEvents: List.unmodifiable(_formEvents),
        running: !finished,
        paused: finished,
        restUntilMs: finished ? 0 : restUntil,
        endedAtMs: finished ? DateTime.now().millisecondsSinceEpoch : 0,
        durationMs: finished
            ? DateTime.now().millisecondsSinceEpoch - current.startedAtMs
            : 0,
      );
      return;
    }

    final engineReps = _squat?.repCount ?? _pushup?.repCount ?? 0;
    state = current.copyWith(
      reps: _sessionReps,
      setReps: engineReps,
      phase: _squat?.phase ?? _pushup?.phase ?? current.phase,
      confidence:
          _squat?.confidence ?? _pushup?.confidence ?? current.confidence,
      instruction: instructionKey ?? current.instruction,
      demoId: demoId,
      formEvents: List.unmodifiable(_formEvents),
    );
  }

  void nextSet() {
    if (_squat != null) _squat!.resetForNextSet();
    if (_pushup != null) _pushup!.resetForNextSet();
    resume();
    state = state.copyWith(setReps: 0, clearInstruction: true, clearDemo: true);
  }

  Future<void> handleSystemEvent(SystemEvent event) async {
    switch (event.type) {
      case SystemEventType.lifecycle:
        if (event.phase == 'paused' || event.phase == 'detached') {
          if (state.running) pause();
          await endCamera();
        } else if (event.phase == 'resumed' &&
            state.running &&
            !state.isFinished) {
          await beginCamera();
        }
      case SystemEventType.permission:
        if (event.granted == true &&
            state.exercise != null &&
            !state.running &&
            !state.isFinished) {
          await beginCamera();
          resume();
        } else if (event.granted == false) {
          state = state.copyWith(
            cameraError:
                'Camera permission denied. Grant access in system settings.',
            running: false,
          );
        }
      case SystemEventType.audio:
      case SystemEventType.unknown:
        break;
    }
  }

  Future<void> saveSession() async {
    final current = state;
    if (current.exercise == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref
        .read(workoutDatabaseProvider)
        .saveSession(
          WorkoutSessionRecord(
            id: '$now-${current.exercise!.wireName}',
            startedAt: current.startedAtMs == 0 ? now : current.startedAtMs,
            endedAt: current.endedAtMs == 0 ? now : current.endedAtMs,
            exercise: current.exercise!.wireName,
            reps: current.reps,
            sets: current.setsCompleted,
            durationMs: current.durationMs,
            payload: {
              'schema_version': 2,
              'plan_id': current.planId,
              'target_reps': current.targetReps,
              'target_sets': current.targetSets,
              'phase': current.phase.wireName,
              'form_events': _formEvents.map((e) => e.toJson()).toList(),
              'pose_backend': current.runtime?.backend ?? 'unknown',
            },
          ),
        );
  }
}

final workoutControllerProvider =
    NotifierProvider<WorkoutController, WorkoutState>(WorkoutController.new);
