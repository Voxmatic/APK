import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/settings/app_settings.dart';
import 'features/workout/workout_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // Persisted settings are loaded before the first frame so there is no flash
  // of default language / onboarding state.
  final container = ProviderContainer();
  await container.read(settingsControllerProvider.notifier).load();
  final settings = container.read(settingsControllerProvider);
  container.read(voiceServiceProvider)
    ..setLanguage(settings.language)
    ..setEnabled(settings.voiceEnabled);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AiGymTrainerApp(),
    ),
  );
}
