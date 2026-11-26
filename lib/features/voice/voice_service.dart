/// Offline voice coaching. Plays pre-generated WAV assets through the platform
/// audio player. Arbitrary text never triggers network TTS.
library;

import 'package:audioplayers/audioplayers.dart';

import '../../core/l10n/strings.dart';
import '../coach/coach_engine.dart';

class VoiceService {
  VoiceService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  AppLanguage _language = AppLanguage.en;
  bool _enabled = true;
  String? _lastPhrase;
  DateTime? _lastPlayed;

  AppLanguage get language => _language;
  bool get enabled => _enabled;

  void setLanguage(AppLanguage language) => _language = language;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stop();
  }

  /// Returns true when a bundled asset was played.
  Future<bool> speak(CoachInstruction instruction) async {
    if (!_enabled) return false;
    final key = instruction.phraseKey;
    final now = DateTime.now();
    if (_lastPhrase == key &&
        _lastPlayed != null &&
        now.difference(_lastPlayed!).inMilliseconds < 1200) {
      return false;
    }
    _lastPhrase = key;
    _lastPlayed = now;

    // Validate through the localized catalogue; no phrase means no playback.
    final strings = AppStrings(_language);
    if (strings.get(key) == key && key != 'pain_stop') return false;

    final asset = 'audio/${_language.code}/$key.wav';
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
      return true;
    } on Object {
      // Missing asset is non-fatal: visual instruction still appears.
      return false;
    }
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
