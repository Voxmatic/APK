/// Offline voice coaching settings and asset playback verification.
/// Speech recognition is not bundled: no unverified model is advertised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  String _status = '';
  static const _phrases = [
    'welcome',
    'start_workout',
    'squat_ready',
    'descend',
    'go_deeper',
    'knee_alignment',
    'hip_sag',
    'trunk_lean',
    'slow_movement',
    'correct_form',
    'good_rep',
    'excellent',
    'set_complete',
    'rest',
    'paused',
    'resumed',
    'stopped',
    'pain_stop',
    'visibility_lost',
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final s = AppStrings(settings.language);
    return Scaffold(
      appBar: AppBar(title: Text(s.get('voice'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: Text(s.get('voice')),
                value: settings.voiceEnabled,
                onChanged: (value) async {
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .setVoiceEnabled(value);
                  ref.read(voiceServiceProvider).setEnabled(value);
                },
              ),
              ListTile(
                title: Text(s.get('language')),
                subtitle: Text(settings.language.nativeName),
                trailing: DropdownButton<AppLanguage>(
                  value: settings.language,
                  underline: const SizedBox(),
                  onChanged: (value) async {
                    if (value == null) return;
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setLanguage(value);
                    ref.read(voiceServiceProvider).setLanguage(value);
                  },
                  items: AppLanguage.values
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(l.nativeName),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              const Divider(color: AppColors.surfaceAlt),
              Text(
                s.get('speech'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                s.get('speech_unavailable'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/models'),
                child: const Text('Model manager'),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 3.2,
                  children: [
                    for (final key in _phrases)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          onPressed: () async {
                            final played = await ref
                                .read(voiceServiceProvider)
                                .speakKey(key);
                            if (mounted) {
                              setState(
                                () => _status = played
                                    ? 'Playing $key (${settings.language.code})'
                                    : ref.read(voiceServiceProvider).lastError,
                              );
                            }
                          },
                          child: Text(
                            key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
