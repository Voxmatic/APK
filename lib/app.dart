library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/camera_calibration/calibration_screen.dart';
import 'features/exercise_library/exercise_library_screen.dart';
import 'features/home/home_screen.dart';
import 'features/live_workout/live_workout_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/summary/summary_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: child,
      bottomNavigationBar: location.startsWith('/workout') || location.startsWith('/calibration')
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
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Exercises'),
                NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Progress'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
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
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/library', builder: (_, _) => const ExerciseLibraryScreen()),
          GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/summary', builder: (_, _) => const SummaryScreen()),
        ],
      ),
      GoRoute(
        path: '/calibration/:exerciseId',
        builder: (_, state) =>
            CalibrationScreen(exerciseId: state.pathParameters['exerciseId'] ?? 'squat'),
      ),
      GoRoute(
        path: '/workout/:exerciseId',
        builder: (_, state) =>
            LiveWorkoutScreen(exerciseId: state.pathParameters['exerciseId'] ?? 'squat'),
      ),
    ],
  );
});

class AiGymTrainerApp extends ConsumerWidget {
  const AiGymTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'AI Gym Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
