// voice_service.dart
// Speech-to-text (speech_to_text) and text-to-speech (flutter_tts) wrapper
// with language auto-detection (Devanagari / Hinglish -> hi-IN, else en-US).

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const _localeIds = <String, String>{
  'English': 'en_US',
  'Hindi': 'hi_IN',
  'Hinglish': 'hi_IN',
  'Telugu': 'te_IN',
  'Tamil': 'ta_IN',
  'Kannada': 'kn_IN',
  'Malayalam': 'ml_IN',
  'Bengali': 'bn_IN',
  'Gujarati': 'gu_IN',
  'Bhojpuri': 'hi_IN',
  'Punjabi': 'pa_IN',
  'Odia': 'or_IN',
  'Urdu': 'ur_PK',
};

const _hinglishWords = [
  'hai', 'kya', 'kaise', 'nahi', 'mera', 'meri', 'mere', 'tum', 'aap', 'karo',
  'kar', 'banao', 'bata', 'batao', 'kal', 'aaj', 'kholo', 'chalao', 'haan',
  'acha', 'achha', 'theek', 'kitne', 'baje', 'mujhe', 'muze', 'hum', 'ho',
];

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;

  bool get isListening => _stt.isListening;

  Future<bool> _init() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(onError: (e) => debugPrint('STT error: ${e.errorMsg}'));
    return _sttReady;
  }

  /// STT locale for the chosen conversation language (null = device default).
  String? sttLocale(String language) => _localeIds[language];

  static String detectTtsLocale(String text, String language) {
    if (language != 'Auto') {
      final id = _localeIds[language];
      if (id != null) return id.replaceAll('_', '-');
    }
    if (RegExp(r'[ऀ-ॿ]').hasMatch(text)) return 'hi-IN';
    final words = text.toLowerCase().split(RegExp(r'[^a-z]+'));
    final hits = words.where(_hinglishWords.contains).length;
    if (hits >= 2) return 'hi-IN';
    return 'en-US';
  }

  Future<bool> listen({
    required String? localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(double level) onLevel,
    required VoidCallback onDone,
  }) async {
    if (!await _init()) return false;
    await _stt.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: (db) {
        // db roughly -2..10 on Android
        onLevel(((db + 2) / 12).clamp(0.0, 1.0));
      },
      onResult: (r) {
        onResult(r.recognizedWords, r.finalResult);
        if (r.finalResult) onDone();
      },
      listenOptions: stt.SpeechListenOptions(partialResults: true, cancelOnError: true),
    );
    return true;
  }

  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> speak(String text, {required String tone, required String language}) async {
    final clean = text.replaceAll(RegExp(r'[*_`#]'), '');
    final locale = detectTtsLocale(clean, language);
    await _tts.setLanguage(locale);
    // Android TTS exposes one voice per locale on most devices, so tones are
    // approximated through pitch / rate.
    final pitch = {
      'Aoede': 1.25,
      'Kore': 1.12,
      'Fenrir': 0.7,
      'Puck': 1.0,
      'Charon': 0.85,
    }[tone] ?? 1.0;
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(clean);
  }

  Future<void> stopSpeaking() => _tts.stop();
}
