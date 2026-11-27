/// Regression coverage for M0 crash C1 and C2. The original failure was an
/// unguarded `camera.start` Future in `initState`; these tests inject the exact
/// native failure as typed data and assert the UI degrades instead of crashing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gym_trainer/core/platform/pose_channel.dart';
import 'package:ai_gym_trainer/features/live_workout/camera_preview.dart';
import 'package:ai_gym_trainer/features/live_workout/live_workout_screen.dart';
import 'package:ai_gym_trainer/features/workout/workout_controller.dart';

import '../helpers/fake_bridge.dart';
import '../helpers/silent_voice.dart';

ProviderScope buildScope({
  required FakePlatformBridge bridge,
  required Widget child,
  SilentVoiceService? voice,
}) {
  return ProviderScope(
    overrides: [
      platformBridgeProvider.overrideWithValue(bridge),
      cameraPreviewBuilderProvider.overrideWithValue(
        () => const SizedBox.expand(),
      ),
      voiceServiceProvider.overrideWithValue(voice ?? SilentVoiceService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'camera.start failure is rendered as a retryable error, not thrown',
    (tester) async {
      final bridge = FakePlatformBridge(
        startResult: const PlatformResult(
          ok: false,
          code: 'CAMERA_START_FAILED',
          message: 'PreviewView is not attached',
        ),
      );
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        buildScope(
          bridge: bridge,
          child: const LiveWorkoutScreen(exerciseId: 'squat'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Restore before asserting: flutter_test rejects assertions while onError
      // is overridden.
      FlutterError.onError = previous;

      expect(
        errors,
        isEmpty,
        reason: 'No platform error may escape into the Flutter error zone.',
      );
      expect(
        find.textContaining('PreviewView is not attached'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(bridge.calls, contains('start'));
    },
  );

  testWidgets('successful start keeps the session running', (tester) async {
    final bridge = FakePlatformBridge(
      cameraStatusValue: const CameraStatus(
        running: false,
        permissionGranted: false,
      ),
      permissionResult: const PlatformResult(ok: true, granted: true),
    );
    await tester.pumpWidget(
      buildScope(
        bridge: bridge,
        child: const LiveWorkoutScreen(exerciseId: 'pushup'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(bridge.calls, containsAll(['permission', 'initialize', 'start']));
    expect(find.textContaining('CAMERA'), findsNothing);
    expect(find.textContaining('0/5'), findsOneWidget);
  });

  testWidgets('pending permission never calls start and shows a retry', (
    tester,
  ) async {
    final bridge = FakePlatformBridge(
      permissionResult: const PlatformResult(
        ok: true,
        granted: false,
        pending: true,
      ),
      cameraStatusValue: const CameraStatus(
        running: false,
        permissionGranted: false,
      ),
    );
    await tester.pumpWidget(
      buildScope(
        bridge: bridge,
        child: const LiveWorkoutScreen(exerciseId: 'squat'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(bridge.calls, isNot(contains('start')));
    expect(
      find.textContaining('Waiting for camera permission'),
      findsOneWidget,
    );
  });
}
