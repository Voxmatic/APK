/// Offline voice coaching. Only bundled WAV assets are played; arbitrary text
/// never triggers network TTS. Failures are reported as state, not swallowed.
library;

import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../coach/coach_engine.dart';

class VoiceService {
  VoiceService({AudioPlayer? player}) : _player = player;

  /// The audio plugin is created only when a phrase is actually played. This
  /// keeps startup and headless tests free of platform-channel side effects.
  AudioPlayer? _player;

  AudioPlayer get player => _player ??= AudioPlayer();
  AppLanguage _language = AppLanguage.en;
  bool _enabled = true;
  String? _lastPhrase;
  DateTime? _lastPlayed;
  Set<String>? _assetIndex;
  String _lastError = '';

  AppLanguage get language => _language;
  bool get enabled => _enabled;
  String get lastError => _lastError;

  /// Coach instruction id -> bundled phrase key. This is a policy mapping;
  /// no model output can introduce a new phrase.
  static const Map<String, String> phraseByInstruction = {
    'pain_stop': 'pain_stop',
    'knee_alignment': 'knee_alignment',
    'hip_sag': 'hip_sag',
    'go_deeper': 'go_deeper',
    'trunk_lean': 'trunk_lean',
    'camera_hint': 'visibility_lost',
    'control_movement': 'correct_form',
    'body_alignment': 'incorrect_body_alignment',
    'good_rep': 'good_rep',
    'excellent': 'excellent',
    'set_complete': 'set_complete',
    'show_demo': 'show_demo',
  };

  void setLanguage(AppLanguage language) {
    _language = language;
    _lastPhrase = null;
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stop();
  }

  Future<Set<String>> _assets() async {
    final cached = _assetIndex;
    if (cached != null) return cached;
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifest) as Map<String, dynamic>;
      _assetIndex = decoded.keys.toSet();
    } on Object {
      _assetIndex = const <String>{};
    }
    return _assetIndex!;
  }

  /// Returns true only when a bundled asset actually started playback.
  Future<bool> speak(CoachInstruction instruction) async {
    if (!_enabled) return false;
    final key = phraseByInstruction[instruction.id] ?? instruction.phraseKey;
    final now = DateTime.now();
    if (_lastPhrase == key &&
        _lastPlayed != null &&
        now.difference(_lastPlayed!).inMilliseconds < 1000) {
      return false;
    }
    _lastPhrase = key;
    _lastPlayed = now;

    final asset = 'assets/audio/${_language.code}/$key.wav';
    if (!(await _assets()).contains(asset)) {
      _lastError = 'Missing bundled phrase: $asset';
      return false;
    }
    try {
      await player.stop();
      await player.play(AssetSource(asset));
      _lastError = '';
      return true;
    } on Object catch (e) {
      _lastError = 'Audio playback failed: $e';
      return false;
    }
  }

  /// Directly play one bundled phrase by key (used by the voice test screen).
  Future<bool> speakKey(String key) async {
    if (!_enabled) return false;
    final asset = 'assets/audio/${_language.code}/$key.wav';
    if (!(await _assets()).contains(asset)) {
      _lastError = 'Missing bundled phrase: $asset';
      return false;
    }
    try {
      await player.stop();
      await player.play(AssetSource(asset));
      _lastError = '';
      return true;
    } on Object catch (e) {
      _lastError = 'Audio playback failed: $e';
      return false;
    }
  }

  Future<void> stop() => _player?.stop() ?? Future.value();

  Future<void> dispose() => _player?.dispose() ?? Future.value();
}
