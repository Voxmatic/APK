/// Persisted user preferences. All values live in SharedPreferences on the
/// device; nothing is transmitted.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

enum VisualizationMode { skeleton, ghost, video }

extension VisualizationModeX on VisualizationMode {
  String get wireName => switch (this) {
    VisualizationMode.skeleton => 'skeleton',
    VisualizationMode.ghost => 'ghost',
    VisualizationMode.video => 'video',
  };

  static VisualizationMode fromWire(String value) => switch (value) {
    'ghost' => VisualizationMode.ghost,
    'video' => VisualizationMode.video,
    _ => VisualizationMode.skeleton,
  };
}

class AppSettings {
  const AppSettings({
    this.languageCode = 'en',
    this.voiceEnabled = true,
    this.visualizationMode = VisualizationMode.skeleton,
    this.onboardingComplete = false,
    this.selectedPlanId = 'beginner',
    this.modelInstallConsent = false,
  });

  final String languageCode;
  final bool voiceEnabled;
  final VisualizationMode visualizationMode;
  final bool onboardingComplete;
  final String selectedPlanId;
  final bool modelInstallConsent;

  AppLanguage get language => AppLanguage.fromCode(languageCode);

  AppSettings copyWith({
    String? languageCode,
    bool? voiceEnabled,
    VisualizationMode? visualizationMode,
    bool? onboardingComplete,
    String? selectedPlanId,
    bool? modelInstallConsent,
  }) => AppSettings(
    languageCode: languageCode ?? this.languageCode,
    voiceEnabled: voiceEnabled ?? this.voiceEnabled,
    visualizationMode: visualizationMode ?? this.visualizationMode,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    selectedPlanId: selectedPlanId ?? this.selectedPlanId,
    modelInstallConsent: modelInstallConsent ?? this.modelInstallConsent,
  );

  static AppSettings fromPrefs(SharedPreferences prefs) => AppSettings(
    languageCode: prefs.getString('language_code') ?? 'en',
    voiceEnabled: prefs.getBool('voice_enabled') ?? true,
    visualizationMode: VisualizationModeX.fromWire(
      prefs.getString('visualization_mode') ?? 'skeleton',
    ),
    onboardingComplete: prefs.getBool('onboarding_complete') ?? false,
    selectedPlanId: prefs.getString('selected_plan_id') ?? 'beginner',
    modelInstallConsent: prefs.getBool('model_install_consent') ?? false,
  );

  Future<void> persist(SharedPreferences prefs) async {
    await prefs.setString('language_code', languageCode);
    await prefs.setBool('voice_enabled', voiceEnabled);
    await prefs.setString('visualization_mode', visualizationMode.wireName);
    await prefs.setBool('onboarding_complete', onboardingComplete);
    await prefs.setString('selected_plan_id', selectedPlanId);
    await prefs.setBool('model_install_consent', modelInstallConsent);
  }
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences? _prefs;

  @override
  AppSettings build() => const AppSettings();

  /// Called once from main() before runApp so all screens start from real
  /// persisted values rather than a flash of defaults.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    state = AppSettings.fromPrefs(_prefs!);
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    await next.persist(_prefs ?? await SharedPreferences.getInstance());
  }

  Future<void> setLanguage(AppLanguage language) =>
      _update(state.copyWith(languageCode: language.code));

  Future<void> setVoiceEnabled(bool enabled) =>
      _update(state.copyWith(voiceEnabled: enabled));

  Future<void> setVisualizationMode(VisualizationMode mode) =>
      _update(state.copyWith(visualizationMode: mode));

  Future<void> completeOnboarding() =>
      _update(state.copyWith(onboardingComplete: true));

  Future<void> selectPlan(String planId) =>
      _update(state.copyWith(selectedPlanId: planId));

  Future<void> setModelInstallConsent(bool granted) =>
      _update(state.copyWith(modelInstallConsent: granted));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
