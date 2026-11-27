/// Exercise catalogue driven by bundled metadata. Only exercises with a
/// verified deterministic engine and a local demo are startable.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _entries = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/exercises/metadata/exercises.json'),
    ) as Map<String, dynamic>;
    final list = (decoded['exercises'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['status'] == 'IMPLEMENTED')
        .toList();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    return Scaffold(
      appBar: AppBar(title: Text(s.get('nav_library'))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final id = entry['id'] as String;
                final demo = entry['demo'] as String?;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryDim,
                      child: Icon(
                        Icons.fitness_center,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      s.get(id),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${(entry['camera_view'] as String? ?? 'front')} view · ${s.get('start_workout')}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: demo != null
                        ? IconButton(
                            icon: const Icon(
                              Icons.play_circle_outline,
                              color: AppColors.primary,
                            ),
                            onPressed: () => context.push('/demo/$id'),
                          )
                        : null,
                    onTap: () => context.go('/calibration/$id'),
                  ),
                );
              },
            ),
    );
  }
}
