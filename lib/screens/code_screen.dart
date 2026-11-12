// code_screen.dart
// Code Studio: describe an app/site -> Gemini writes real code -> live preview
// in a WebView (HTML projects) with automatic JS-error capture and "Fix" flow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/gemini_service.dart';
import '../services/voice_service.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/orb.dart';

const _codeSystem = '''You are an expert senior software engineer producing production-grade code.
Rules:
- If the user asks for a website, web app, game, tool, prototype or UI (or doesn't name a language), output ONE complete self-contained HTML file with inline CSS and JS, mobile-responsive, modern design, no external dependencies unless a CDN is essential.
- If the user explicitly asks for another language (Python, Flutter/Dart, Java, etc.), output a single complete, runnable file in that language.
- Output ONLY the code. No explanations, no markdown fences.
- The code must work without errors on first run.''';

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});
  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final input = TextEditingController();
  final voice = VoiceService.instance;
  late final WebViewController web;
  String code = '';
  String lastPrompt = '';
  bool busy = false;
  bool showPreview = true;
  bool fixAsked = false;

  bool get isHtml => code.trimLeft().toLowerCase().startsWith('<!doctype') || code.trimLeft().toLowerCase().startsWith('<html');

  @override
  void initState() {
    super.initState();
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('JarvisErr', onMessageReceived: (m) => _onRuntimeError(m.message));
  }

  String _strip(String s) {
    var t = s.trim();
    final m = RegExp(r'```[a-zA-Z]*\n([\s\S]*?)```').firstMatch(t);
    if (m != null) t = m.group(1)!.trim();
    return t;
  }

  String _instrument(String html) {
    const hook = '<script>window.onerror=function(m,s,l,c){JarvisErr.postMessage(m+" (line "+l+")");};'
        'window.addEventListener("unhandledrejection",function(e){JarvisErr.postMessage("Promise: "+e.reason);});</script>';
    final lower = html.toLowerCase();
    final i = lower.indexOf('<head>');
    if (i >= 0) return html.substring(0, i + 6) + hook + html.substring(i + 6);
    return hook + html;
  }

  void _render() {
    if (isHtml) {
      fixAsked = false;
      web.loadHtmlString(_instrument(code));
    }
  }

  Future<void> _generate(String prompt) async {
    if (prompt.trim().isEmpty || busy) return;
    final app = context.read<AppState>();
    setState(() {
      busy = true;
      lastPrompt = prompt;
    });
    try {
      final r = await GeminiService.ask(
        apiKey: app.apiKey,
        model: app.model,
        system: _codeSystem,
        history: [
          {'role': 'user', 'text': prompt}
        ],
        temperature: 0.4,
      );
      code = _strip(r);
      showPreview = isHtml;
      _render();
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _onRuntimeError(String err) async {
    if (!mounted || fixAsked) return;
    fixAsked = true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Is code me kuch gadbad hai'),
        content: Text('Error: $err\n\nFix karun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, fix karo')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final app = context.read<AppState>();
    setState(() => busy = true);
    try {
      final r = await GeminiService.ask(
        apiKey: app.apiKey,
        model: app.model,
        system: _codeSystem,
        history: [
          {'role': 'user', 'text': 'Original request: $lastPrompt\n\nCurrent code:\n$code\n\nIt throws this runtime error: $err\n\nReturn the complete fixed file only.'}
        ],
        temperature: 0.2,
      );
      code = _strip(r);
      fixAsked = false;
      _render();
    } catch (e) {
      if (mounted) snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _voiceInput() async {
    final app = context.read<AppState>();
    if (app.micOn) {
      await voice.stopListening();
      app.setMic(false);
      return;
    }
    final st = await Permission.microphone.request();
    if (!st.isGranted) {
      if (mounted) snack(context, 'Microphone permission chahiye');
      return;
    }
    app.setMic(true);
    await voice.listen(
      localeId: voice.sttLocale(app.language),
      onLevel: app.setLevel,
      onResult: (t, fin) {
        input.text = t;
        if (fin) app.setMic(false);
      },
      onDone: () => app.setMic(false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;
    final hasCode = code.isNotEmpty;

    // Hand-off from Home ("Jarvis mere liye todo app banao")
    if (app.pendingCodePrompt != null && !busy) {
      final prompt = app.takeCodePrompt()!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate(prompt));
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GlassCircle(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () {
                if (hasCode) {
                  setState(() => code = '');
                } else {
                  app.setTab(0);
                }
              },
            ),
            GlassCircle(
              icon: Icons.add_rounded,
              onTap: () => setState(() {
                code = '';
                input.clear();
              }),
            ),
          ]),
          Expanded(child: hasCode ? _workspace(p) : _empty(p)),
          const SizedBox(height: 10),
          Glass(
            radius: 32,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(children: [
              GlassCircle(
                icon: Icons.content_paste_rounded,
                size: 46,
                onTap: () async {
                  final d = await Clipboard.getData('text/plain');
                  if (d?.text != null) input.text = '${input.text} ${d!.text}'.trim();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: input,
                  style: ts(p),
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: hasCode ? 'Change karne ke liye likho...' : 'A prototype..',
                    hintStyle: ts(p, sub: true),
                    border: InputBorder.none,
                  ),
                ),
              ),
              GestureDetector(
                onTap: busy
                    ? null
                    : () {
                        final t = input.text.trim();
                        if (t.isEmpty) return;
                        input.clear();
                        if (hasCode) {
                          _generate('Original request: $lastPrompt\n\nCurrent code:\n$code\n\nApply this change and return the complete updated file only: $t');
                        } else {
                          _generate(t);
                        }
                      },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF3F6BFF)])),
                  child: busy
                      ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 28),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          WaveBall(size: 54, onTap: _voiceInput),
        ]),
      ),
    );
  }

  Widget _empty(Palette p) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Glass(
            radius: 70,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 34),
            child: Text('Build something\nCreative', textAlign: TextAlign.center, style: ts(p, size: 30, w: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          Text('Bring a new product, internal tool,\nor entire company to life.',
              textAlign: TextAlign.center, style: ts(p, size: 16, sub: true)),
        ]),
      );

  Widget _workspace(Palette p) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(children: [
        Row(children: [
          if (isHtml) ...[
            _tab(p, 'Preview', showPreview, () => setState(() => showPreview = true)),
            const SizedBox(width: 8),
          ],
          _tab(p, 'Code', !showPreview || !isHtml, () => setState(() => showPreview = false)),
          const Spacer(),
          if (isHtml) IconButton(onPressed: _render, icon: Icon(Icons.refresh_rounded, color: p.text), tooltip: 'Reload'),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              snack(context, 'Code copy ho gaya');
            },
            icon: Icon(Icons.copy_rounded, color: p.text),
            tooltip: 'Copy',
          ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: (showPreview && isHtml)
                ? WebViewWidget(controller: web)
                : Container(
                    color: const Color(0xFF0F1420),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(code,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFFD6E2FF), height: 1.4)),
                      ),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _tab(Palette p, String label, bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Glass(
          radius: 20,
          active: on,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(label, style: ts(p, size: 14, w: on ? FontWeight.w900 : FontWeight.w600)),
        ),
      );
}
