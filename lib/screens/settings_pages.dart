// settings_pages.dart
// Settings sub-pages: Gemini API, AI Persona & Voice, Memory Bank,
// System Permissions, App Control, Privacy. All backed by real logic.

import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gemini_service.dart';
import '../services/memory_service.dart';
import '../services/voice_service.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';

// ───────────────────────── Gemini API ─────────────────────────
class ApiScreen extends StatefulWidget {
  const ApiScreen({super.key});
  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> {
  late final TextEditingController key;
  late final TextEditingController model;
  bool hide = true;
  bool testing = false;
  String ping = '-- ms';
  String? status;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    key = TextEditingController(text: app.apiKey);
    model = TextEditingController(text: app.model);
  }

  Future<void> _test() async {
    setState(() {
      testing = true;
      status = null;
    });
    try {
      final ms = await GeminiService.ping(key.text, model.text.trim());
      setState(() {
        ping = '$ms ms';
        status = 'Connection OK';
      });
    } catch (e) {
      setState(() {
        ping = '-- ms';
        status = e.toString().replaceFirst('Exception: ', '');
      });
    }
    setState(() => testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;
    final configured = key.text.trim().isNotEmpty;
    const presets = ['gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-2.5-pro'];

    return SubPage(
      title: 'API & Connection',
      subtitle: 'Gemini REST (generateContent)',
      children: [
        Glass(
          radius: 30,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              pill(p, configured ? 'KEY CONFIGURED' : 'NO KEY', configured ? const Color(0xFF2E9E5B) : const Color(0xFFD32F2F)),
              const Spacer(),
              Text('Ping: $ping', style: ts(p, size: 14, w: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text('generativelanguage.googleapis.com', style: ts(p, size: 13, sub: true)),
            if (status != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(status!, style: ts(p, size: 13.5, color: status == 'Connection OK' ? const Color(0xFF2E9E5B) : const Color(0xFFD32F2F)))),
            const SizedBox(height: 8),
            PrimaryButton(label: testing ? 'Testing...' : 'Test Connection & Latency', icon: Icons.bolt_rounded, onTap: testing ? null : _test, color: const Color(0xFF2563EB)),
          ]),
        ),
        sectionLabel(p, 'Gemini API key'),
        Glass(
          radius: 30,
          child: Column(children: [
            TextField(
              controller: key,
              obscureText: hide,
              style: ts(p),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded), onPressed: () => setState(() => hide = !hide)),
              ),
            ),
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.paste_rounded),
                label: const Text('Paste'),
                onPressed: () async {
                  final d = await Clipboard.getData('text/plain');
                  if (d?.text != null) setState(() => key.text = d!.text!.trim());
                },
              ),
              TextButton.icon(icon: const Icon(Icons.clear_rounded), label: const Text('Clear'), onPressed: () => setState(() => key.clear())),
              const Spacer(),
              TextButton(onPressed: () => launchUrl(Uri.parse('https://aistudio.google.com/apikey'), mode: LaunchMode.externalApplication), child: const Text('Get free key')),
            ]),
          ]),
        ),
        sectionLabel(p, 'Model engine'),
        Glass(
          radius: 30,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(children: [
            ...presets.map((m) => RadioListTile<String>(
                  value: m,
                  groupValue: model.text,
                  activeColor: p.accent,
                  title: Text(m, style: ts(p, w: FontWeight.w800)),
                  onChanged: (v) => setState(() => model.text = v!),
                )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: model,
                style: ts(p),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Custom model name'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Save & Apply Configuration',
          icon: Icons.save_rounded,
          onTap: () {
            app.update(() {
              app.apiKey = key.text.trim();
              app.model = model.text.trim().isEmpty ? 'gemini-2.0-flash' : model.text.trim();
            });
            snack(context, 'Saved');
          },
        ),
      ],
    );
  }
}

// ───────────────────────── Persona & Voice ─────────────────────────
class PersonaScreen extends StatefulWidget {
  const PersonaScreen({super.key});
  @override
  State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  late String persona, tone;
  late final TextEditingController name, addr;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    persona = app.persona;
    tone = app.voiceTone;
    name = TextEditingController(text: app.userName);
    addr = TextEditingController(text: app.address);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;
    return SubPage(
      title: 'AI Persona',
      subtitle: 'Personality, name and voice',
      children: [
        Glass(
          radius: 30,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: kPersonas.entries
                .map((e) => RadioListTile<String>(
                      value: e.key,
                      groupValue: persona,
                      activeColor: p.accent,
                      title: Text(e.key, style: ts(p, w: FontWeight.w900)),
                      subtitle: Text(e.value, style: ts(p, size: 13, sub: true)),
                      onChanged: (v) => setState(() => persona = v!),
                    ))
                .toList(),
          ),
        ),
        sectionLabel(p, 'You'),
        Glass(
          radius: 30,
          child: Column(children: [
            TextField(controller: name, style: ts(p), decoration: const InputDecoration(labelText: 'Your name')),
            TextField(controller: addr, style: ts(p), decoration: const InputDecoration(labelText: 'How should the persona address you?')),
          ]),
        ),
        sectionLabel(p, 'Voice tone'),
        Glass(
          radius: 30,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: kVoiceTones.entries
                .map((e) => RadioListTile<String>(
                      value: e.key,
                      groupValue: tone,
                      activeColor: p.accent,
                      title: Text(e.key, style: ts(p, w: FontWeight.w900)),
                      subtitle: Text(e.value, style: ts(p, size: 13, sub: true)),
                      onChanged: (v) {
                        setState(() => tone = v!);
                        VoiceService.instance.speak('Namaste, main aapki awaaz hoon.', tone: tone, language: app.language);
                      },
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        Text('Note: Android TTS ek hi voice deta hai, isliye tones pitch se alag kiye gaye hain.', style: ts(p, size: 12.5, sub: true)),
        PrimaryButton(
          label: 'Activate Persona',
          icon: Icons.bolt_rounded,
          onTap: () {
            app.update(() {
              app.persona = persona;
              app.voiceTone = tone;
              if (name.text.trim().isNotEmpty) app.userName = name.text.trim();
              if (addr.text.trim().isNotEmpty) app.address = addr.text.trim();
            });
            snack(context, '$persona activated');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ───────────────────────── Memory Bank ─────────────────────────
class MemoryBankScreen extends StatefulWidget {
  const MemoryBankScreen({super.key});
  @override
  State<MemoryBankScreen> createState() => _MemoryBankScreenState();
}

class _MemoryBankScreenState extends State<MemoryBankScreen> {
  String q = '';

  String _d(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    final mem = context.watch<MemoryService>();
    final hits = mem.search(q);
    return SubPage(
      title: 'Neural Memory Bank',
      subtitle: '${mem.threads.length} conversations saved on this device',
      children: [
        Glass(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            style: ts(p),
            decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded, color: p.sub), hintText: 'Search memories...', border: InputBorder.none),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.backup_rounded),
              label: const Text('Backup (copy JSON)'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mem.exportJson()));
                snack(context, 'Memory JSON clipboard me copy ho gaya');
              },
            ),
          ),
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              label: const Text('Clear all', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Saari memory delete karein?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) mem.clearAll();
              },
            ),
          ),
        ]),
        if (hits.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('Kuch nahi mila.', style: ts(p, sub: true))),
        ...hits.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Glass(
                radius: 24,
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${h.msg.role == 'user' ? 'You' : 'Jarvis'} • ${h.thread.title} • ${_d(h.msg.ts)}', style: ts(p, size: 12, w: FontWeight.w800, sub: true)),
                  const SizedBox(height: 4),
                  Text(h.msg.text, maxLines: 6, overflow: TextOverflow.ellipsis, style: ts(p, size: 14.5)),
                ]),
              ),
            )),
      ],
    );
  }
}

// ───────────────────────── Permissions ─────────────────────────
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  static final items = <_Perm>[
    _Perm('Microphone Access', Icons.mic_rounded, Permission.microphone),
    _Perm('Precise Location', Icons.location_on_rounded, Permission.locationWhenInUse),
    _Perm('Notifications', Icons.notifications_rounded, Permission.notification),
    _Perm('Display Over Other Apps', Icons.layers_rounded, Permission.systemAlertWindow),
    _Perm('Contacts', Icons.contacts_rounded, Permission.contacts),
    _Perm('Phone calls', Icons.call_rounded, Permission.phone),
    _Perm('Camera & flashlight', Icons.camera_alt_rounded, Permission.camera),
    _Perm('Nearby Bluetooth devices', Icons.bluetooth_rounded, Permission.bluetoothConnect),
    _Perm('Background battery access', Icons.battery_charging_full_rounded, Permission.ignoreBatteryOptimizations),
  ];
  final Map<Permission, bool> granted = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final i in items) {
      granted[i.perm] = await i.perm.isGranted;
    }
    if (mounted) setState(() {});
  }

  Future<void> _grant(_Perm i) async {
    final s = await i.perm.request();
    if (s.isPermanentlyDenied) await openAppSettings();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    return SubPage(
      title: 'System Authorizations',
      subtitle: 'Jarvis - Neural Assistant needs these to work fully',
      children: [
        Glass(
          radius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            ...items.map((i) {
              final ok = granted[i.perm] ?? false;
              return SettingsRow(
                icon: i.icon,
                title: i.title,
                trailing: ok
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E5B))
                    : TextButton(onPressed: () => _grant(i), child: const Text('Grant')),
              );
            }),
            SettingsRow(
              icon: Icons.accessibility_new_rounded,
              title: 'Accessibility Service',
              subtitle: 'Android settings me manually enable karna padta hai',
              trailing: TextButton(
                onPressed: () async {
                  if (Platform.isAndroid) await const AndroidIntent(action: 'android.settings.ACCESSIBILITY_SETTINGS').launch();
                },
                child: const Text('Open'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'GRANT ALL PERMISSIONS',
          icon: Icons.done_all_rounded,
          onTap: () async {
            for (final i in items) {
              if (!(granted[i.perm] ?? false)) await i.perm.request();
            }
            _refresh();
          },
        ),
        PrimaryButton(label: 'OPEN SYSTEM APP SETTINGS', color: const Color(0xFF2563EB), icon: Icons.settings_rounded, onTap: openAppSettings),
        Text('Kuch permissions (Overlay, Battery) Android ke settings page par jaake allow karni padti hain.', style: ts(p, size: 12.5, sub: true)),
      ],
    );
  }
}

class _Perm {
  final String title;
  final IconData icon;
  final Permission perm;
  _Perm(this.title, this.icon, this.perm);
}

// ───────────────────────── App Control ─────────────────────────
class AppControlScreen extends StatelessWidget {
  const AppControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    Widget cmd(String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Glass(
            radius: 26,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(p, size: 16, w: FontWeight.w900)),
              const SizedBox(height: 6),
              ...lines.map((l) => Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $l', style: ts(p, size: 14, sub: true)))),
            ]),
          ),
        );
    return SubPage(
      title: 'Hands-Free Control',
      subtitle: 'Voice commands jo abhi kaam karte hain',
      children: [
        cmd('Apps', ['"YouTube kholo" / "open YouTube"', '"WhatsApp kholo"', '"camera kholo"']),
        cmd('Phone & settings', ['"settings kholo"', '"bluetooth kholo", "wifi kholo"', '"call 9876543210" (dialer khulta hai)']),
        cmd('Info', ['"time kya hai", "kitne baje"', '"aaj ki date"', '"search flutter tutorial" (Google)']),
        cmd('Coding', ['"mere liye todo app banao" -> Code Studio me code ban jaata hai']),
        cmd('Memory', ['"kal maine kya bola tha website ke liye?"']),
        PrimaryButton(
          label: 'Open Accessibility Settings',
          icon: Icons.accessibility_new_rounded,
          onTap: () async {
            if (Platform.isAndroid) await const AndroidIntent(action: 'android.settings.ACCESSIBILITY_SETTINGS').launch();
          },
        ),
        Text(
          'Honest note: WhatsApp me message type karna ya doosri apps me tap/scroll karna ke liye ek native Android AccessibilityService chahiye. '
          'Ye is Flutter project me included nahi hai (alag Kotlin code lagta hai). Abhi apps open hoti hain, andar ka control nahi.',
          style: ts(p, size: 13, sub: true),
        ),
      ],
    );
  }
}

// ───────────────────────── Privacy ─────────────────────────
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().palette;
    return SubPage(
      title: 'Privacy & Data',
      children: [
        Glass(
          radius: 28,
          child: Text(
            '• Chats, memory aur settings sirf is phone me save hote hain.\n'
            '• AI jawab ke liye aapka text (aur voice ka text) Google Gemini API ko HTTPS par jaata hai.\n'
            '• Weather ke liye location Open-Meteo / OpenStreetMap ko jaati hai.\n'
            '• API key phone me SharedPreferences me store hoti hai.\n'
            '• Voice biometrics / speaker lock is version me nahi hai.',
            style: ts(p, size: 15),
          ),
        ),
      ],
    );
  }
}
