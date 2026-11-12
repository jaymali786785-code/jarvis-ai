// gemini_service.dart
// Talks to the Gemini REST API (generateContent). Needs a user API key
// from https://aistudio.google.com/apikey (free tier available).

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  /// [history] items: {'role': 'user'|'model', 'text': '...'}
  static Future<String> ask({
    required String apiKey,
    required String model,
    required String system,
    required List<Map<String, String>> history,
    double temperature = 0.7,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('API key set nahi hai. Settings > Gemini API me key daalo.');
    }
    // Gemini needs the conversation to start with a user turn.
    final h = List<Map<String, String>>.from(history);
    while (h.isNotEmpty && h.first['role'] != 'user') {
      h.removeAt(0);
    }
    if (h.isEmpty) throw Exception('Empty prompt');

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${apiKey.trim()}');
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': h
          .map((m) => {
                'role': m['role'] == 'user' ? 'user' : 'model',
                'parts': [
                  {'text': m['text']}
                ]
              })
          .toList(),
      'generationConfig': {'temperature': temperature},
    };
    final res = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) {
      String msg = res.body;
      try {
        msg = jsonDecode(res.body)['error']['message'] ?? msg;
      } catch (_) {}
      throw Exception('Gemini error ${res.statusCode}: $msg');
    }
    final j = jsonDecode(res.body);
    final parts = j['candidates']?[0]?['content']?['parts'] as List?;
    if (parts == null) throw Exception('Gemini ne khaali jawab diya (safety filter ho sakta hai).');
    return parts.map((p) => (p['text'] ?? '').toString()).join();
  }

  /// Returns round-trip latency in ms.
  static Future<int> ping(String apiKey, String model) async {
    final sw = Stopwatch()..start();
    await ask(
      apiKey: apiKey,
      model: model,
      system: 'Reply with the single word OK.',
      history: [
        {'role': 'user', 'text': 'ping'}
      ],
      temperature: 0,
    );
    return sw.elapsedMilliseconds;
  }
}
