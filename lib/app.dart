/// Router and shell. Immersive camera/demo routes hide the bottom navigation;
/// all other routes are reachable from it or from settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/strings.dart';
import 'core/platform/pose_channel.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/camera_calibration/calibration_screen.dart';
import 'features/compatibility/compatibility_screen.dart';
import 'features/diagnostics/diagnostics_screen.dart';
import 'features/exercise_library/exercise_library_screen.dart';
import 'features/help/help_screen.dart';
import 'features/home/home_screen.dart';
import 'features/learning/demo_screen.dart';
import 'features/live_workout/live_workout_screen.dart';
import 'features/local_ai/local_ai_screen.dart';
import 'features/models/model_manager_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/permissions/permission_screen.dart';
import 'features/plans/plan_selection_screen.dart';
import 'features/privacy/privacy_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/summary/summary_screen.dart';
import 'features/voice/voice_screen.dart';
import 'features/workout/rest_screen.dart';
import 'features/workout/workout_controller.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final immersive = [
      '/workout',
      '/calibration',
      '/rest',
      '/demo',
      '/onboarding',
      '/permissions',
      '/compatibility',
      '/plans',
      '/models',
      '/voice',
      '/local-ai',
      '/diagnostics',
      '/privacy',
      '/help',
    ].any(location.startsWith);
    final s = AppStrings(ref.watch(settingsControllerProvider).language);

    return Scaffold(
      body: child,
      bottomNavigationBar: immersive
          ? null
          : NavigationBar(
              selectedIndex: _index(location),
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/home');
                  case 1:
                    context.go('/library');
                  case 2:
                    context.go('/progress');
                  case 3:
                    context.go('/settings');
                }
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: s.get('nav_home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.fitness_center_outlined),
                  selectedIcon: const Icon(Icons.fitness_center),
                  label: s.get('nav_library'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.show_chart_outlined),
                  selectedIcon: const Icon(Icons.show_chart),
                  label: s.get('nav_progress'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: s.get('nav_settings'),
                ),
              ],
            ),
    );
  }

  int _index(String location) {
    if (location.startsWith('/library')) return 1;
    if (location.startsWith('/progress')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final onboarded = ref.read(settingsControllerProvider).onboardingComplete;
      final location = state.matchedLocation;
      if (!onboarded && location != '/onboarding') return '/onboarding';
      if (onboarded && location == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/permissions',
        builder: (_, _) => const PermissionScreen(),
      ),
      GoRoute(
        path: '/compatibility',
        builder: (_, _) => const CompatibilityScreen(),
      ),
      GoRoute(path: '/plans', builder: (_, _) => const PlanSelectionScreen()),
      GoRoute(path: '/models', builder: (_, _) => const ModelManagerScreen()),
      GoRoute(path: '/voice', builder: (_, _) => const VoiceScreen()),
      GoRoute(path: '/local-ai', builder: (_, _) => const LocalAiScreen()),
      GoRoute(
        path: '/diagnostics',
        builder: (_, _) => const DiagnosticsScreen(),
      ),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(
        path: '/demo/:exerciseId',
        builder: (_, state) => DemoScreen(
          exerciseId: state.pathParameters['exerciseId'] ?? 'squat',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/library',
            builder: (_, _) => const ExerciseLibraryScreen(),
          ),
          GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/summary', builder: (_, _) => const SummaryScreen()),
        ],
      ),
      GoRoute(
        path: '/calibration/:exerciseId',
        builder: (_, state) => CalibrationScreen(
          exerciseId: state.pathParameters['exerciseId'] ?? 'squat',
        ),
      ),
      GoRoute(
        path: '/workout/:exerciseId',
        builder: (_, state) => LiveWorkoutScreen(
          exerciseId: state.pathParameters['exerciseId'] ?? 'squat',
        ),
      ),
      GoRoute(
        path: '/rest/:exerciseId',
        builder: (_, state) => RestScreen(
          exerciseId: state.pathParameters['exerciseId'] ?? 'squat',
        ),
      ),
    ],
  );
});

class AiGymTrainerApp extends ConsumerStatefulWidget {
  const AiGymTrainerApp({super.key});

  @override
  ConsumerState<AiGymTrainerApp> createState() => _AiGymTrainerAppState();
}

class _AiGymTrainerAppState extends ConsumerState<AiGymTrainerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final phase = switch (state) {
      AppLifecycleState.paused => 'paused',
      AppLifecycleState.resumed => 'resumed',
      AppLifecycleState.detached => 'detached',
      AppLifecycleState.inactive => 'inactive',
      AppLifecycleState.hidden => 'hidden',
    };
    ref
        .read(workoutControllerProvider.notifier)
        .handleSystemEvent(
          SystemEvent(type: SystemEventType.lifecycle, phase: phase),
        );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'AI Gym Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
