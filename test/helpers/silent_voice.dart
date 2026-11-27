import 'package:ai_gym_trainer/features/coach/coach_engine.dart';
import 'package:ai_gym_trainer/features/voice/voice_service.dart';

/// Voice service for tests: records phrases without touching audioplugins.
class SilentVoiceService extends VoiceService {
  final List<String> spoken = [];

  @override
  Future<bool> speak(CoachInstruction instruction) async {
    spoken.add(instruction.phraseKey);
    return true;
  }

  @override
  Future<bool> speakKey(String key) async {
    spoken.add(key);
    return true;
  }
}
