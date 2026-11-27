/// Model manager. Only the pose landmarker is bundled and required. Optional
/// artifacts are downloaded only after explicit consent, with size check,
/// SHA-256 verification and native registration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/model_catalog.dart';
import '../../core/models/model_manager.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  bool _consent = false;
  String _verification = '';

  @override
  void initState() {
    super.initState();
    ref.read(modelManagerProvider.notifier).load();
    _verify();
  }

  Future<void> _verify() async {
    final status = await ref.read(platformBridgeProvider).poseStatus();
    if (!mounted) return;
    setState(() {
      _verification = status.modelReady
          ? '${status.modelId} · ${status.modelSha256}'
          : status.lastError.isNotEmpty
          ? status.lastError
          : 'not_loaded';
    });
  }

  String _errorText(AppStrings s, String code) => switch (code) {
    'disk_space_low' => s.get('disk_space_low'),
    'checksum_mismatch' => s.get('checksum_mismatch'),
    'consent_required' =>
      'Consent is required before installing optional models.',
    'size_mismatch' => 'Downloaded size does not match the manifest.',
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final s = AppStrings(settings.language);
    final state = ref.watch(modelManagerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.get('model_install'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.get('model_readiness'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                _verification,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              if (!settings.modelInstallConsent)
                SwitchListTile(
                  title: const Text('Allow optional model downloads'),
                  subtitle: const Text(
                    'Downloads use the exact manifest URL and verify SHA-256 before install.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _consent,
                  onChanged: (value) async {
                    setState(() => _consent = value);
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setModelInstallConsent(value);
                  },
                ),
              const SizedBox(height: 8),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: state.catalog.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final model = state.catalog[index];
                          final installed = state.isInstalled(model.id);
                          final progress = state.progress[model.id];
                          final error = state.errors[model.id];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        installed
                                            ? Icons.check_circle
                                            : Icons.download_outlined,
                                        color: installed
                                            ? AppColors.success
                                            : AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          model.id,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        model.required
                                            ? s.get('model_installed')
                                            : s.get('model_optional'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${model.version} · ${model.sizeBytes == null ? 'unknown size' : formatBytes(model.sizeBytes!)} · ${model.license}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  if (model.sha256 != null)
                                    Text(
                                      'SHA-256 ${model.sha256}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  if (progress != null)
                                    LinearProgressIndicator(
                                      value: progress,
                                      color: AppColors.primary,
                                      minHeight: 6,
                                    ),
                                  if (error != null)
                                    Text(
                                      _errorText(s, error),
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _verify,
                                        child: Text(s.get('verify')),
                                      ),
                                      if (!model.isBundled && installed)
                                        TextButton(
                                          onPressed: () => ref
                                              .read(
                                                modelManagerProvider.notifier,
                                              )
                                              .remove(model),
                                          child: Text(s.get('remove')),
                                        ),
                                      if (!model.isBundled && !installed)
                                        FilledButton(
                                          onPressed: () => ref
                                              .read(
                                                modelManagerProvider.notifier,
                                              )
                                              .install(
                                                model,
                                                consent: settings
                                                    .modelInstallConsent,
                                              ),
                                          child: Text(s.get('install')),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
