/// Privacy facts and local data controls. No analytics, no cloud inference.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _busy = false;
  String _message = '';

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(settingsProvider));
    final facts = [
      s.get('privacy_details'),
      'Camera frames are processed in native code and never leave the device.',
      'Workout payloads are AES-256-GCM encrypted with a device-bound key before they reach SQLite.',
      'Bundled speech phrases are local WAV assets; there is no network text-to-speech.',
      'Optional model downloads happen only after you enable them in the model manager.',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.get('privacy'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: facts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          facts[index],
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _message,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.download),
                label: Text(s.get('export_data')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_forever),
                label: Text(s.get('delete_all')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(workoutDatabaseProvider).exportJson();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ai_gym_trainer_export.json');
      await file.writeAsString(json);
      if (mounted) setState(() => _message = 'Exported to ${file.path}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(workoutDatabaseProvider).deleteAll();
      if (mounted) setState(() => _message = 'All local workout data deleted');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
