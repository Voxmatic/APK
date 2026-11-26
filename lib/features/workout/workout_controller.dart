/// Workout session state machine driven by real pose frames.
/// All counting is deterministic; no event is fabricated for the UI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/platform/pose_channel.dart';
import '../../core/storage/workout_db.dart';
import '../coach/coach_engine.dart';
import '../exercise_intelligence/biomechanics.dart';
import '../exercise_intelligence/events.dart';
import '../exercise_intelligence/pushup_engine.dart';
import '../exercise_intelligence/squat_engine.dart';
import '../voice/voice_service.dart';

final platformBridgeProvider = Provider<PlatformBridge>((ref) => PlatformBridge());
final poseStreamProvider = StreamProvider<PoseFrame>((ref) {
  ref.keepAlive();
  return ref.watch(platformBridgeProvider).poseStream();
});
final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());
final workoutDatabaseProvider = Provider<WorkoutDatabase>((ref) => WorkoutDatabase());
final settingsProvider = Provider<AppLanguage>((ref) => AppLanguage.en);

class WorkoutState {
  const WorkoutState({
    this.exercise,
    this.running = false,
    this.paused = false,
    this.reps = 0,
    this.sets = 0,
    this.phase = MovementPhase.ready,
    this.confidence = 0,
    this.instruction,
    this.demoId,
    this.formEvents = const [],
    this.startedAtMs = 0,
  });

  final ExerciseId? exercise;
  final bool running;
  final bool paused;
  final int reps;
  final int sets;
  final MovementPhase phase;
  final double confidence;
  final String? instruction;
  final String? demoId;
  final List<FormCorrectionEvent> formEvents;
  final int startedAtMs;
}

class WorkoutController extends Notifier<WorkoutState> {
  SquatEngine? _squat;
  PushUpEngine? _pushup;
  final CoachEngine _coach = CoachEngine();
  final List<FormCorrectionEvent> _formEvents = [];

  @override
  WorkoutState build() => const WorkoutState();

  void start(ExerciseId exercise, {int targetReps = 10, int targetSets = 3}) {
    _squat = exercise == ExerciseId.squat ? SquatEngine(targetReps: targetReps) : null;
    _pushup = exercise == ExerciseId.pushup ? PushUpEngine() : null;
    _coach.reset();
    _formEvents.clear();
    state = WorkoutState(
      exercise: exercise,
      running: true,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void pause() => state = _copy(running: false, paused: true);

  void resume() => state = _copy(running: true, paused: false);

  void stop() => state = _copy(running: false, paused: false);

  void setLanguage(AppLanguage language) {
    ref.read(voiceServiceProvider).setLanguage(language);
  }

  /// Feed one real pose frame from the native EventChannel.
  void onPoseFrame(PoseFrame frame) {
    final current = state;
    if (!current.running || current.paused || current.exercise == null) return;

    final events = switch (current.exercise!) {
      ExerciseId.squat => _squat?.update(frame) ?? const <ExerciseEvent>[],
      ExerciseId.pushup => _pushup?.update(frame) ?? const <ExerciseEvent>[],
      _ => const <ExerciseEvent>[],
    };
    if (events.isEmpty) return;

    String? instructionKey;
    String? demoId;
    final voice = ref.read(voiceServiceProvider);
    for (final event in events) {
      if (event is FormCorrectionEvent) _formEvents.add(event);
      final coachInstruction = _coach.process(event);
      if (coachInstruction != null) {
        instructionKey = coachInstruction.phraseKey;
        demoId = coachInstruction.visualDemoId;
        voice.speak(coachInstruction);
      }
    }

    final squat = _squat;
    final pushup = _pushup;
    state = _copy(
      reps: squat?.repCount ?? pushup?.repCount ?? current.reps,
      phase: squat?.phase ?? pushup?.phase ?? current.phase,
      confidence: squat?.confidence ?? pushup?.confidence ?? current.confidence,
      instruction: instructionKey ?? current.instruction,
      demoId: demoId,
      formEvents: List.unmodifiable(_formEvents),
    );
  }

  Future<void> saveSession() async {
    final current = state;
    if (current.exercise == null) return;
    final db = ref.read(workoutDatabaseProvider);
    await db.saveSession(WorkoutSessionRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: current.startedAtMs,
      endedAt: DateTime.now().millisecondsSinceEpoch,
      exercise: current.exercise!.wireName,
      reps: current.reps,
      sets: current.sets + (current.reps > 0 ? 1 : 0),
      durationMs: DateTime.now().millisecondsSinceEpoch - current.startedAtMs,
      payload: {
        'schema_version': 1,
        'phase': current.phase.wireName,
        'form_events': _formEvents.map((e) => e.toJson()).toList(),
      },
    ));
  }

  WorkoutState _copy({
    bool? running,
    bool? paused,
    int? reps,
    int? sets,
    MovementPhase? phase,
    double? confidence,
    String? instruction,
    String? demoId,
    List<FormCorrectionEvent>? formEvents,
  }) {
    final s = state;
    return WorkoutState(
      exercise: s.exercise,
      running: running ?? s.running,
      paused: paused ?? s.paused,
      reps: reps ?? s.reps,
      sets: sets ?? s.sets,
      phase: phase ?? s.phase,
      confidence: confidence ?? s.confidence,
      instruction: instruction,
      demoId: demoId,
      formEvents: formEvents ?? s.formEvents,
      startedAtMs: s.startedAtMs,
    );
  }
}

final workoutControllerProvider =
    NotifierProvider<WorkoutController, WorkoutState>(WorkoutController.new);
