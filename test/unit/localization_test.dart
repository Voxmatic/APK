import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/core/l10n/strings.dart';

void main() {
  test('English and Hindi have real translations', () {
    expect(AppStrings(AppLanguage.en).get('start_workout'), 'Start Workout');
    expect(
      AppStrings(AppLanguage.hi).get('start_workout'),
      'वर्कआउट शुरू करें',
    );
  });

  test('13 languages are catalogued', () {
    expect(AppLanguage.values.length, 13);
  });

  test('untranslated language falls back to English', () {
    expect(AppStrings(AppLanguage.bn).get('nav_home'), 'Home');
  });

  test('language lookup by code', () {
    expect(AppLanguage.fromCode('hi'), AppLanguage.hi);
    expect(AppLanguage.fromCode('xx'), AppLanguage.en);
  });

  test('every UI key used in lib resolves in both shipped languages', () {
    final used = <String>{};
    final files = <File>[
      File('lib/app.dart'),
      ...Directory('lib/features').listSync(recursive: true).whereType<File>(),
    ];
    final literal = RegExp(r"s\.get\('([^']+)'\)");
    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in literal.allMatches(file.readAsStringSync())) {
        used.add(match.group(1)!);
      }
    }
    // Keys selected at runtime by switch expressions or engine/plan wire names.
    used.addAll(const {
      'live_skeleton',
      'ghost_3d',
      'video_demo',
      'squat',
      'pushup',
      'pain_stop',
      'knee_alignment',
      'hip_sag',
      'go_deeper',
      'trunk_lean',
      'visibility_lost',
      'correct_form',
      'incorrect_body_alignment',
      'good_rep',
      'excellent',
      'set_complete',
      'show_demo',
      'descend',
      'slow_movement',
      'welcome',
      'start_workout',
      'squat_ready',
      'rest',
      'paused',
      'resumed',
      'stopped',
      'plan_beginner',
      'plan_strength',
      'plan_quick',
      'plan_beginner_desc',
      'plan_strength_desc',
      'plan_quick_desc',
    });

    final missingEn =
        used.where((key) => AppStrings(AppLanguage.en).get(key) == key).toList()
          ..sort();
    final missingHi =
        used.where((key) => AppStrings(AppLanguage.hi).get(key) == key).toList()
          ..sort();
    expect(missingEn, isEmpty, reason: 'Missing English keys: $missingEn');
    expect(missingHi, isEmpty, reason: 'Missing Hindi keys: $missingHi');
  });
}
