import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_trainer/core/l10n/strings.dart';

void main() {
  test('English and Hindi have real translations', () {
    expect(AppStrings(AppLanguage.en).get('start_workout'), 'Start Workout');
    expect(AppStrings(AppLanguage.hi).get('start_workout'), 'वर्कआउट शुरू करें');
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
}
