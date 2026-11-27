/// Optional local AI status. The deterministic coach remains authoritative.
/// An LLM is never used to invent a rep, angle, diagnosis or safety decision.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';

class LocalAiScreen extends ConsumerWidget {
  const LocalAiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(settingsControllerProvider).language);
    final facts = [
      'Rep counting and form corrections come from deterministic biomechanics.',
      'Safety stops are rule-based and cannot be overridden by a language model.',
      'The optional GGUF model can be installed from the model manager after consent.',
      'No verified mobile GGUF runtime is bundled in this build, so phrasing stays deterministic.',
      'No prompt, landmark or workout text is sent to a cloud service.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Local AI')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.smart_toy_outlined,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                s.get('model_optional'),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: facts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textMuted,
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
              FilledButton.icon(
                onPressed: () => context.push('/models'),
                icon: const Icon(Icons.model_training),
                label: Text(s.get('model_install')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
