// memory_service.dart
// Neural Memory Bank: every conversation is stored on-device (SharedPreferences
// JSON) so it can be searched, recalled in prompts and backed up.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Msg {
  final String role; // 'user' | 'model'
  final String text;
  final int ts;
  Msg(this.role, this.text, this.ts);
  Map<String, dynamic> toJson() => {'r': role, 't': text, 'ts': ts};
  factory Msg.fromJson(Map<String, dynamic> j) => Msg(j['r'], j['t'], j['ts']);
}

class ChatThread {
  final String id;
  String title;
  int updated;
  final List<Msg> msgs;
  ChatThread(this.id, this.title, this.updated, this.msgs);
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'updated': updated, 'msgs': msgs.map((m) => m.toJson()).toList()};
  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        j['id'],
        j['title'],
        j['updated'],
        (j['msgs'] as List).map((m) => Msg.fromJson(Map<String, dynamic>.from(m))).toList(),
      );
}

class SearchHit {
  final ChatThread thread;
  final Msg msg;
  SearchHit(this.thread, this.msg);
}

class MemoryService extends ChangeNotifier {
  late SharedPreferences _p;
  final List<ChatThread> threads = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('threads');
    if (raw != null) {
      try {
        threads.addAll((jsonDecode(raw) as List).map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }
    _sort();
  }

  void _sort() => threads.sort((a, b) => b.updated.compareTo(a.updated));

  Future<void> _save() => _p.setString('threads', jsonEncode(threads.map((t) => t.toJson()).toList()));

  ChatThread? byId(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Creates a thread and returns its id.
  String newThread({String title = 'New chat'}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    threads.add(ChatThread(id, title, DateTime.now().millisecondsSinceEpoch, []));
    _sort();
    _save();
    notifyListeners();
    return id;
  }

  /// Adds a message; creates the thread if [threadId] doesn't exist yet
  /// (used for the permanent 'voice' thread).
  void add(String threadId, String role, String text, {String? title}) {
    var t = byId(threadId);
    if (t == null) {
      t = ChatThread(threadId, title ?? 'Chat', DateTime.now().millisecondsSinceEpoch, []);
      threads.add(t);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    t.msgs.add(Msg(role, text, now));
    t.updated = now;
    if (t.title == 'New chat' && role == 'user') {
      t.title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
    }
    _sort();
    _save();
    notifyListeners();
  }

  /// Last [n] messages of a thread as Gemini history.
  List<Map<String, String>> recent(String threadId, {int n = 20}) {
    final t = byId(threadId);
    if (t == null) return [];
    final list = t.msgs.length > n ? t.msgs.sublist(t.msgs.length - n) : t.msgs;
    return list.map((m) => {'role': m.role, 'text': m.text}).toList();
  }

  List<SearchHit> search(String q, {int limit = 50}) {
    final query = q.toLowerCase().trim();
    final hits = <SearchHit>[];
    for (final t in threads) {
      for (final m in t.msgs.reversed) {
        if (query.isEmpty || m.text.toLowerCase().contains(query)) {
          hits.add(SearchHit(t, m));
          if (hits.length >= limit) return hits;
        }
      }
    }
    return hits;
  }

  /// Keyword recall used when the user asks "kal maine kya bola tha ...".
  String recallContext(String question) {
    final words = question
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9ऀ-ॿ]+'))
        .where((w) => w.length > 3)
        .toSet();
    final scored = <MapEntry<int, SearchHit>>[];
    for (final t in threads) {
      for (final m in t.msgs) {
        if (m.role != 'user') continue;
        final lower = m.text.toLowerCase();
        final score = words.where(lower.contains).length;
        if (score > 0) scored.add(MapEntry(score, SearchHit(t, m)));
      }
    }
    scored.sort((a, b) => b.key.compareTo(a.key));
    return scored.take(6).map((e) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.value.msg.ts);
      return '- (${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}) ${e.value.msg.text}';
    }).join('\n');
  }

  void deleteThread(String id) {
    threads.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  void clearAll() {
    threads.clear();
    _save();
    notifyListeners();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(threads.map((t) => t.toJson()).toList());
}
