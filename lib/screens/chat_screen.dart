// chat_screen.dart
// Chat tab: list of saved conversations (real, from memory) + thread screen
// that talks to Gemini with the last 20 messages as context.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../services/memory_service.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';

String _fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final hh = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$hh:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) return t;
  final y = now.subtract(const Duration(days: 1));
  if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Yesterday $t';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day} $t';
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mem = context.watch<MemoryService>();
    final p = app.palette;
    final icons = [Icons.forum_outlined, Icons.description_outlined, Icons.lightbulb_outline_rounded];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GlassCircle(icon: Icons.menu_rounded, onTap: () => showMainMenu(context)),
            GlassCircle(
              icon: Icons.add_rounded,
              onTap: () {
                final id = mem.newThread();
                Navigator.of(context).pushNamed('/thread', arguments: id);
              },
            ),
          ]),
          const SizedBox(height: 10),
          Center(
            child: Glass(
              radius: 60,
              width: 320,
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(children: [
                Text('Hi', style: ts(p, size: 44, w: FontWeight.w900)),
                Text('${app.assistantName} • Gemini Live • Active', style: ts(p, size: 15, sub: true)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 26, 0, 12),
            child: Text('Recent chats', style: ts(p, size: 22, w: FontWeight.w600, sub: true)),
          ),
          if (mem.threads.isEmpty)
            Glass(
              child: Text('Abhi koi chat nahi hai. Upar + dabao ya Home par Jarvis se baat karo — saari conversations yahan save hongi.',
                  style: ts(p, sub: true)),
            ),
          ...List.generate(mem.threads.length, (i) {
            final t = mem.threads[i];
            final last = t.msgs.isEmpty ? '' : t.msgs.last.text.replaceAll('\n', ' ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(28)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                onDismissed: (_) => mem.deleteThread(t.id),
                child: Glass(
                  radius: 32,
                  padding: const EdgeInsets.fromLTRB(16, 18, 18, 14),
                  onTap: () => Navigator.of(context).pushNamed('/thread', arguments: t.id),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Glass(
                      circle: true,
                      width: 64,
                      height: 64,
                      padding: EdgeInsets.zero,
                      child: Icon(icons[i % 3], size: 30, color: p.text),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p, size: 19, w: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(last.isEmpty ? 'Empty chat' : last,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p, size: 15, sub: true)),
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: Text(_fmtTime(t.updated), style: ts(p, size: 13, sub: true))),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ThreadScreen extends StatefulWidget {
  final String threadId;
  const ThreadScreen({super.key, required this.threadId});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    final app = context.read<AppState>();
    final mem = context.read<MemoryService>();
    input.clear();
    mem.add(widget.threadId, 'user', text);
    setState(() => busy = true);
    _toBottom();
    try {
      final reply = await GeminiService.ask(
        apiKey: app.apiKey,
        model: app.model,
        system: app.systemPrompt,
        history: mem.recent(widget.threadId, n: 20),
      );
      mem.add(widget.threadId, 'model', reply);
    } catch (e) {
      mem.add(widget.threadId, 'model', 'Error: ${e.toString().replaceFirst('Exception: ', '')}');
    }
    if (mounted) setState(() => busy = false);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mem = context.watch<MemoryService>();
    final p = app.palette;
    final t = mem.byId(widget.threadId);
    final msgs = t?.msgs ?? [];
    return Scaffold(
      backgroundColor: p.bgTop,
      body: BubbleBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                GlassCircle(icon: Icons.arrow_back_ios_new_rounded, size: 46, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Text(t?.title ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p, size: 20, w: FontWeight.w900))),
              ]),
            ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(child: Text('Kuch bhi poochho...', style: ts(p, sub: true)))
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: msgs.length + (busy ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == msgs.length) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(alignment: Alignment.centerLeft, child: Text('${app.assistantName} soch raha hai...', style: ts(p, sub: true))),
                          );
                        }
                        final m = msgs[i];
                        final me = m.role == 'user';
                        return Align(
                          alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                            child: Glass(
                              radius: 24,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              tint: me ? p.accent : Colors.white,
                              child: SelectableText(m.text, style: ts(p, size: 15.5)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Glass(
                radius: 30,
                padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      style: ts(p),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: 'Message...', hintStyle: ts(p, sub: true), border: InputBorder.none),
                    ),
                  ),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF6D4AFF), Color(0xFF4A7BFF)])),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
