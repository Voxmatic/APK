library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppLanguage _language = AppLanguage.en;
  bool _voice = true;

  @override
  void initState() {
    super.initState();
    _language = ref.read(voiceServiceProvider).language;
    _voice = ref.read(voiceServiceProvider).enabled;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(_language);
    return Scaffold(
      appBar: AppBar(title: Text(s.get('nav_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.language, color: AppColors.primary),
            title: Text(s.get('language')),
            subtitle: Text(_language.nativeName),
            trailing: DropdownButton<AppLanguage>(
              value: _language,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _language = value);
                ref.read(voiceServiceProvider).setLanguage(value);
                ref.read(workoutControllerProvider.notifier).setLanguage(value);
              },
              items: AppLanguage.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.nativeName)))
                  .toList(),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: AppColors.primary),
            title: Text(s.get('voice')),
            value: _voice,
            onChanged: (value) {
              setState(() => _voice = value);
              ref.read(voiceServiceProvider).setEnabled(value);
            },
          ),
          const Divider(color: AppColors.surfaceAlt),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textMuted),
            title: Text(s.get('privacy')),
            subtitle: const Text('All workout data stays on this device.', style: TextStyle(fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined, color: AppColors.textMuted),
            title: Text(s.get('export_data')),
            onTap: () async {
              final rows = await ref.read(workoutDatabaseProvider).history();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${rows.length} workout sessions stored locally')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.accent),
            title: Text(s.get('delete_all')),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(s.get('delete_all')),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(workoutDatabaseProvider).deleteAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All local data deleted')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
