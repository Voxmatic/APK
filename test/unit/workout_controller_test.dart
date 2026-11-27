import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gym_trainer/core/platform/pose_channel.dart';
import 'package:ai_gym_trainer/core/storage/workout_db.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/biomechanics.dart';
import 'package:ai_gym_trainer/features/exercise_intelligence/events.dart';
import 'package:ai_gym_trainer/features/workout/workout_controller.dart';

import '../helpers/fake_bridge.dart';
import '../helpers/pose_fixtures.dart';
import '../helpers/silent_voice.dart';

void main() {
  ProviderContainer makeContainer(FakePlatformBridge bridge) =>
      ProviderContainer(
        overrides: [
          platformBridgeProvider.overrideWithValue(bridge),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          workoutDatabaseProvider.overrideWithValue(
            MemoryWorkoutStore(cipher: NativePayloadCipher(bridge)),
          ),
        ],
      );

  test(
    'real frame sequence completes a set and persists an encrypted payload',
    () async {
      final bridge = FakePlatformBridge();
      final container = makeContainer(bridge);
      addTearDown(container.dispose);
      final controller = container.read(workoutControllerProvider.notifier);

      controller.start(ExerciseId.squat, targetReps: 2, targetSets: 1);
      expect(await controller.beginCamera(), isTrue);

      var t = 0;
      for (final depth in [0.0, 0.7, 1.0, 0.7, 0.0, 0.7, 1.0, 0.7, 0.0]) {
        controller.onPoseFrame(squatFrame(depth: depth, t: t++ * 100));
      }
      final state = container.read(workoutControllerProvider);
      expect(state.reps, 2);
      expect(state.setsCompleted, 1);
      expect(state.isFinished, isTrue);
      expect(state.instruction, 'set_complete');

      await controller.saveSession();
      final rows = await container.read(workoutDatabaseProvider).history();
      expect(rows.length, 1);
      expect(rows.single.reps, 2);
      expect(rows.single.payload['plan_id'], '');
      expect(bridge.calls, contains('encrypt'));
    },
  );

  test('permission denial is a state, not an exception', () async {
    final bridge = FakePlatformBridge(
      cameraStatusValue: const CameraStatus(
        running: false,
        permissionGranted: false,
      ),
      permissionResult: PlatformResult(
        ok: false,
        code: 'PERMISSION_DENIED',
        message: 'denied',
        granted: false,
      ),
    );
    final container = makeContainer(bridge);
    addTearDown(container.dispose);
    final controller = container.read(workoutControllerProvider.notifier);
    controller.start(ExerciseId.pushup);

    expect(await controller.beginCamera(), isFalse);
    expect(container.read(workoutControllerProvider).cameraError, 'denied');
    expect(container.read(workoutControllerProvider).running, isFalse);
  });

  test('malformed native frame is surfaced as poseError and ignored', () async {
    final container = makeContainer(FakePlatformBridge());
    addTearDown(container.dispose);
    final controller = container.read(workoutControllerProvider.notifier);
    controller.start(ExerciseId.squat);

    controller.onPoseFrame(
      const PoseFrame(
        landmarks: [],
        timestampMs: 42,
        error: 'Malformed pose event',
      ),
    );
    expect(
      container.read(workoutControllerProvider).poseError,
      'Malformed pose event',
    );
    expect(container.read(workoutControllerProvider).reps, 0);
  });
}
