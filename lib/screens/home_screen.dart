// home_screen.dart
// Home: voice-reactive golden orb, mic toggle, live weather, shortcut cards.
// Voice pipeline: STT -> local commands / code router / Gemini -> TTS.

import 'dart:async';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/commands.dart';
import '../services/gemini_service.dart';
import '../services/memory_service.dart';
import '../services/voice_service.dart';
import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/orb.dart';
import '../widgets/sheets.dart';
import 'settings_pages.dart';

const kVoiceThread = 'voice';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final voice = VoiceService.instance;
  String heard = '';
  String lastReply = '';
  int _lastReq = 0;
  WeatherData? weather;
  String? weatherError;
  Timer? _wt;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _wt = Timer.periodic(const Duration(minutes: 10), (_) => _loadWeather());
  }

  @override
  void dispose() {
    _wt?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    try {
      final w = await WeatherService.fetch();
      if (mounted) setState(() {
        weather = w;
        weatherError = null;
      });
    } catch (e) {
      if (mounted) setState(() => weatherError = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleMic() async {
    final app = context.read<AppState>();
    if (app.micOn) {
      await voice.stopListening();
      app.setMic(false);
      return;
    }
    await voice.stopSpeaking();
    final st = await Permission.microphone.request();
    if (!st.isGranted) {
      if (mounted) snack(context, 'Microphone permission chahiye (Settings > System Permissions)');
      return;
    }
    heard = '';
    app.setMic(true);
    app.setOrb(OrbMode.listening);
    final ok = await voice.listen(
      localeId: voice.sttLocale(app.language),
      onLevel: app.setLevel,
      onResult: (t, fin) {
        if (mounted) setState(() => heard = t);
        if (fin) _handle(t);
      },
      onDone: () {},
    );
    if (!ok) {
      app.setMic(false);
      if (mounted) snack(context, 'Speech recognition available nahi hai (Google app / Speech Services check karo)');
    }
  }

  Future<void> _handle(String text) async {
    final app = context.read<AppState>();
    final mem = context.read<MemoryService>();
    app.setMic(false);
    if (text.trim().isEmpty) {
      app.setOrb(OrbMode.idle);
      return;
    }
    mem.add(kVoiceThread, 'user', text, title: 'Voice chat');
    String reply;
    try {
      if (Commands.isCodeRequest(text)) {
        reply = 'Theek hai ${app.address}, Code section me coding shuru kar raha hoon.';
        app.requestCode(text);
      } else {
        final local = await Commands.tryLocal(text);
        if (local != null) {
          reply = local;
        } else {
          app.setOrb(OrbMode.thinking);
          var system = app.systemPrompt;
          if (Commands.isRecallRequest(text)) {
            final ctx = mem.recallContext(text);
            if (ctx.isNotEmpty) system += '\nRelevant past user messages from memory:\n$ctx';
          }
          reply = await GeminiService.ask(
            apiKey: app.apiKey,
            model: app.model,
            system: system,
            history: mem.recent(kVoiceThread, n: 20),
          );
        }
      }
    } catch (e) {
      reply = e.toString().replaceFirst('Exception: ', '');
    }
    mem.add(kVoiceThread, 'model', reply);
    if (mounted) setState(() => lastReply = reply);
    if (!app.silent) {
      app.setOrb(OrbMode.speaking);
      await voice.speak(reply, tone: app.voiceTone, language: app.language);
    }
    app.setOrb(OrbMode.idle);
  }

  String _greeting(AppState app) {
    final h = DateTime.now().hour;
    final g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return '$g, ${app.userName}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;

    // Voice tab in the nav asks Home to toggle the mic.
    if (app.micRequest != _lastReq) {
      _lastReq = app.micRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleMic());
    }

    final micOn = app.micOn;
    final pillColor = micOn ? const Color(0xFF00B8D4) : const Color(0xFFD32F2F);

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
                final id = context.read<MemoryService>().newThread();
                Navigator.of(context).pushNamed('/thread', arguments: id);
              },
            ),
          ]),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Center(
              child: Glass(
                radius: 60,
                width: 300,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(children: [
                  Text('Hi', style: ts(p, size: 44, w: FontWeight.w900)),
                  Text('${app.assistantName} • Gemini Live • Active', style: ts(p, size: 15, sub: true)),
                ]),
              ),
            ),
          ),
          Center(child: Text('Welcome back,', style: ts(p, size: 17, w: FontWeight.w800))),
          Center(child: Text(app.userName, style: ts(p, size: 15, sub: true))),
          const SizedBox(height: 4),
          Center(child: GestureDetector(onTap: _toggleMic, child: const JarvisOrb(size: 330))),
          const SizedBox(height: 4),
          Center(
            child: Glass(
              radius: 30,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              onTap: _toggleMic,
              active: micOn,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: pillColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(micOn ? 'LISTENING • TAP TO STOP' : 'MIC MUTED (OFF) • TAP TO TALK',
                    style: ts(p, size: 15, w: FontWeight.w900, color: pillColor, spacing: 1.4)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              micOn
                  ? (heard.isEmpty ? 'Boliye, main sun raha hoon...' : '"$heard"')
                  : (lastReply.isNotEmpty ? lastReply : 'Microphone is muted • Tap mic to unmute'),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: ts(p, size: 14, sub: true),
            ),
          ),
          const SizedBox(height: 16),
          _weatherCard(p),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _miniCard(p, Icons.screen_share_rounded, 'Screen', 'Share screen', () async {
                if (!Platform.isAndroid) return;
                try {
                  await const AndroidIntent(action: 'android.settings.CAST_SETTINGS').launch();
                } catch (_) {
                  if (mounted) snack(context, 'Is phone par Cast settings nahi khul paayi');
                }
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(p, Icons.layers_rounded, 'Memories', 'Recall Core', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryBankScreen()));
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(p, Icons.language_rounded, 'Language', app.language, () => showLanguageSheet(context)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _weatherCard(Palette p) {
    final w = weather;
    return Glass(
      radius: 36,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      onTap: _loadWeather,
      child: w == null
          ? Row(children: [
              Expanded(
                child: Text(weatherError ?? 'Weather load ho raha hai...', style: ts(p, size: 15, sub: true)),
              ),
              if (weatherError != null) Text('Tap to retry', style: ts(p, size: 12, color: p.accent, w: FontWeight.w800)),
            ])
          : Row(children: [
              Text('${w.temp.round()}°C', style: ts(p, size: 40, w: FontWeight.w900)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${w.description} • ${w.city}', style: ts(p, size: 18, w: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Feels ${w.feels.round()}° • H ${w.high.round()}° L ${w.low.round()}° • ${w.humidity}% humidity',
                      style: ts(p, size: 14, sub: true)),
                ]),
              ),
              Glass(
                circle: true,
                width: 56,
                height: 56,
                padding: EdgeInsets.zero,
                child: Icon(w.isClear ? Icons.wb_sunny_rounded : Icons.cloud_rounded,
                    color: const Color(0xFF2979FF), size: 30),
              ),
            ]),
    );
  }

  Widget _miniCard(Palette p, IconData icon, String title, String sub, VoidCallback onTap) {
    return Glass(
      radius: 28,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 26),
        const SizedBox(height: 8),
        Text(title, style: ts(p, size: 16, w: FontWeight.w900)),
        Text(sub, style: ts(p, size: 13, sub: true), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
