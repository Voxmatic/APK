/// Offline safety and setup guidance. No external links are required to train.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../workout/workout_controller.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(settingsProvider));
    final tips = [
      'Place the phone 1.5–2 m away so your head, hips, knees and ankles are all visible.',
      'Use even, indirect light. Avoid a bright window directly behind you.',
      'Move at a controlled pace: the coach flags rapid, uncontrolled repetitions.',
      'Stop immediately if you feel pain, dizziness or unusual shortness of breath.',
      'Calibrate again after changing camera position or switching exercises.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Help & safety')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: tips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.tips_and_updates_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tips[index],
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => context.push('/calibration/squat'),
                child: Text(s.get('calibration')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
