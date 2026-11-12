// app_state.dart
// Global app state: settings, persona, theme palette, orb state, navigation tab.
// Everything user-configurable is persisted in SharedPreferences.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OrbMode { idle, listening, thinking, speaking }

class Palette {
  final Color bgTop, bgBottom, text, sub, accent;
  final bool dark;
  const Palette(this.bgTop, this.bgBottom, this.text, this.sub, this.accent, this.dark);
}

const kPersonas = <String, String>{
  'Jarvis Pro': 'Intelligent, witty & strategic',
  'Girlfriend Mode (Pari)': 'Caring, warm & supportive',
  'Boyfriend Mode (Kabir)': 'Charismatic, confident & protective',
  'TechGPT X Mode': 'Ultra-fast code architecture',
};

const kVoiceTones = <String, String>{
  'Aoede': 'Warm female',
  'Kore': 'Gentle calm female',
  'Fenrir': 'Deep protective male',
  'Puck': 'Crisp modern dynamic male',
  'Charon': 'Butler',
};

const kLanguages = <String>[
  'Auto', 'English', 'Hindi', 'Hinglish', 'Telugu', 'Tamil', 'Kannada',
  'Malayalam', 'Bengali', 'Gujarati', 'Bhojpuri', 'Punjabi', 'Odia', 'Urdu',
];

class AppState extends ChangeNotifier {
  late SharedPreferences _p;

  String userName = 'jay';
  String address = 'Sir';
  String persona = 'Jarvis Pro';
  String voiceTone = 'Puck';
  String language = 'Auto';
  String apiKey = '';
  String model = 'gemini-2.0-flash';
  String themeName = 'Light';
  int customColor = 0xFFE10600;
  bool silent = false;

  int tab = 0;
  bool micOn = false;
  OrbMode orb = OrbMode.idle;
  double level = 0; // 0..1 microphone / speech energy
  String? pendingCodePrompt;
  int micRequest = 0;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    userName = _p.getString('userName') ?? userName;
    address = _p.getString('address') ?? address;
    persona = _p.getString('persona') ?? persona;
    voiceTone = _p.getString('voiceTone') ?? voiceTone;
    language = _p.getString('language') ?? language;
    apiKey = _p.getString('apiKey') ?? apiKey;
    model = _p.getString('model') ?? model;
    themeName = _p.getString('themeName') ?? themeName;
    customColor = _p.getInt('customColor') ?? customColor;
    silent = _p.getBool('silent') ?? silent;
  }

  Future<void> _persist() async {
    await _p.setString('userName', userName);
    await _p.setString('address', address);
    await _p.setString('persona', persona);
    await _p.setString('voiceTone', voiceTone);
    await _p.setString('language', language);
    await _p.setString('apiKey', apiKey);
    await _p.setString('model', model);
    await _p.setString('themeName', themeName);
    await _p.setInt('customColor', customColor);
    await _p.setBool('silent', silent);
  }

  /// Change persisted settings.
  void update(VoidCallback fn) {
    fn();
    _persist();
    notifyListeners();
  }

  // ---- transient (not persisted) ----
  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void requestMic() {
    tab = 0;
    micRequest++;
    notifyListeners();
  }

  void requestCode(String prompt) {
    pendingCodePrompt = prompt;
    tab = 4;
    notifyListeners();
  }

  String? takeCodePrompt() {
    final s = pendingCodePrompt;
    pendingCodePrompt = null;
    return s;
  }

  void setMic(bool v) {
    micOn = v;
    if (!v && orb == OrbMode.listening) orb = OrbMode.idle;
    if (!v) level = 0;
    notifyListeners();
  }

  void setOrb(OrbMode m) {
    orb = m;
    notifyListeners();
  }

  void setLevel(double v) {
    level = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  // ---- derived ----
  String get assistantName {
    switch (persona) {
      case 'Girlfriend Mode (Pari)':
        return 'Pari';
      case 'Boyfriend Mode (Kabir)':
        return 'Kabir';
      case 'TechGPT X Mode':
        return 'TechGPT X';
      default:
        return 'Jarvis';
    }
  }

  Palette get palette {
    switch (themeName) {
      case 'Dark':
        return const Palette(Color(0xFF0B1026), Color(0xFF1B1146), Colors.white, Color(0xFFB6BDD6), Color(0xFF00E5FF), true);
      case 'Red':
        return const Palette(Color(0xFF1A0507), Color(0xFF3A0A10), Colors.white, Color(0xFFE0B4B8), Color(0xFFFF3B30), true);
      case 'Sunset':
        return const Palette(Color(0xFFFFE8DC), Color(0xFFFFC9B0), Color(0xFF3B1F14), Color(0xFF7A5545), Color(0xFFE8590C), false);
      case 'Custom':
        final c = Color(customColor);
        return Palette(Color.lerp(c, Colors.white, 0.85)!, Color.lerp(c, Colors.white, 0.6)!,
            const Color(0xFF111111), const Color(0xFF555555), c, false);
      default:
        return const Palette(Color(0xFFEEF3FB), Color(0xFFD3E4F5), Color(0xFF0B1220), Color(0xFF4A5568), Color(0xFF2563EB), false);
    }
  }

  /// Orb accent follows theme.
  Color get orbColor => themeName == 'Light' ? const Color(0xFFFFB300) : palette.accent == const Color(0xFF00E5FF) ? const Color(0xFFFFC107) : palette.accent;

  String get systemPrompt {
    final style = {
      'Jarvis Pro': 'You are JARVIS, a witty, strategic, highly capable AI butler like the one from Iron Man. Be concise and sharp.',
      'Girlfriend Mode (Pari)': 'You are Pari, a caring, warm and supportive companion. Be affectionate but respectful and concise.',
      'Boyfriend Mode (Kabir)': 'You are Kabir, a charismatic, confident, protective companion. Be warm and concise.',
      'TechGPT X Mode': 'You are TechGPT X, an ultra-fast senior software architect. Prefer precise, practical, production-grade answers.',
    }[persona]!;
    final lang = language == 'Auto'
        ? 'Reply in the same language the user used (Hindi, Hinglish or English).'
        : 'Reply in $language.';
    return '$style The user\'s name is $userName; address them as "$address" occasionally. $lang '
        'Keep spoken replies short (1-3 sentences) unless asked for detail. '
        'Current date/time: ${DateTime.now().toIso8601String()}.';
  }
}
