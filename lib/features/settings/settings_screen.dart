/// Settings are persisted immediately on-device. Export writes a real local
/// JSON file; delete removes all persisted sessions and coach events.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final s = AppStrings(settings.language);
    return Scaffold(
      appBar: AppBar(title: Text(s.get('nav_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.language, color: AppColors.primary),
            title: Text(s.get('language')),
            subtitle: Text(settings.language.nativeName),
            trailing: DropdownButton<AppLanguage>(
              value: settings.language,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              onChanged: (value) async {
                if (value == null) return;
                await ref
                    .read(settingsControllerProvider.notifier)
                    .setLanguage(value);
                if (mounted) ref.read(voiceServiceProvider).setLanguage(value);
              },
              items: AppLanguage.values
                  .map(
                    (l) =>
                        DropdownMenuItem(value: l, child: Text(l.nativeName)),
                  )
                  .toList(),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: AppColors.primary),
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
            leading: const Icon(
              Icons.visibility_outlined,
              color: AppColors.primary,
            ),
            title: Text(s.get('visualization')),
            subtitle: Text(
              s.get(switch (settings.visualizationMode) {
                VisualizationMode.skeleton => 'live_skeleton',
                VisualizationMode.ghost => 'ghost_3d',
                VisualizationMode.video => 'video_demo',
              }),
            ),
            onTap: () => _chooseVisualization(settings, s),
          ),
          const Divider(color: AppColors.surfaceAlt),
          _navTile(
            icon: Icons.model_training,
            title: s.get('model_install'),
            subtitle: s.get('model_readiness'),
            onTap: () => context.push('/models'),
          ),
          _navTile(
            icon: Icons.record_voice_over,
            title: s.get('speech'),
            subtitle: s.get('voice'),
            onTap: () => context.push('/voice'),
          ),
          _navTile(
            icon: Icons.smart_toy_outlined,
            title: 'Local AI',
            subtitle: s.get('model_optional'),
            onTap: () => context.push('/local-ai'),
          ),
          _navTile(
            icon: Icons.monitor_heart_outlined,
            title: s.get('diagnostics'),
            subtitle: s.get('device_ram'),
            onTap: () => context.push('/diagnostics'),
          ),
          _navTile(
            icon: Icons.privacy_tip_outlined,
            title: s.get('privacy'),
            subtitle: s.get('privacy_details'),
            onTap: () => context.push('/privacy'),
          ),
          _navTile(
            icon: Icons.help_outline,
            title: 'Help & safety',
            subtitle: s.get('pain_stop'),
            onTap: () => context.push('/help'),
          ),
          const Divider(color: AppColors.surfaceAlt),
          ListTile(
            leading: const Icon(
              Icons.download_outlined,
              color: AppColors.primary,
            ),
            title: Text(s.get('export_data')),
            enabled: !_busy,
            onTap: () => _export(s),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.accent),
            title: Text(s.get('delete_all')),
            enabled: !_busy,
            onTap: () => _deleteAll(s),
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 2, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
    onTap: onTap,
  );

  Future<void> _chooseVisualization(AppSettings settings, AppStrings s) async {
    final mode = await showModalBottomSheet<VisualizationMode>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in VisualizationMode.values)
              ListTile(
                title: Text(
                  s.get(switch (option) {
                    VisualizationMode.skeleton => 'live_skeleton',
                    VisualizationMode.ghost => 'ghost_3d',
                    VisualizationMode.video => 'video_demo',
                  }),
                ),
                trailing: option == settings.visualizationMode
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
          ],
        ),
      ),
    );
    if (mode != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setVisualizationMode(mode);
    }
  }

  Future<void> _export(AppStrings s) async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(workoutDatabaseProvider).exportJson();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ai_gym_trainer_export.json');
      await file.writeAsString(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.get('export_data')}: ${file.path}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll(AppStrings s) async {
    final confirm = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.get('delete_all')),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.get('delete_all')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(workoutDatabaseProvider).deleteAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local workout data deleted')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
