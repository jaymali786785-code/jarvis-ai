// settings_screen.dart
// Settings & Intelligence main list. Each row opens a real sub-page / sheet.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';
import 'settings_pages.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _editName(BuildContext context) async {
    final app = context.read<AppState>();
    final ctl = TextEditingController(text: app.userName);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aapka naam'),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) app.update(() => app.userName = v);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;
    final hasKey = app.apiKey.trim().isNotEmpty;

    Widget divider() => Divider(height: 1, color: p.sub.withOpacity(0.25));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [
          Text('Settings & Intelligence', style: ts(p, size: 29, w: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('System preferences & neural configuration', style: ts(p, size: 15, sub: true)),
          const SizedBox(height: 18),
          Glass(
            radius: 36,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Glass(circle: true, width: 70, height: 70, padding: EdgeInsets.zero, child: Icon(Icons.person_rounded, color: p.accent, size: 36)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.userName, style: ts(p, size: 28, w: FontWeight.w900)),
                    Text('JARVIS OPERATOR • PRIMARY USER', style: ts(p, size: 13, w: FontWeight.w700, sub: true, spacing: 1.2)),
                  ]),
                ),
                GlassCircle(icon: Icons.edit_rounded, size: 46, onTap: () => _editName(context)),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 8, children: [
                pill(p, hasKey ? 'API KEY SET' : 'API KEY MISSING', hasKey ? const Color(0xFF2E9E5B) : const Color(0xFFD32F2F),
                    icon: hasKey ? Icons.verified_user_rounded : Icons.error_outline_rounded),
                pill(p, app.persona.toUpperCase(), p.accent, icon: Icons.emoji_emotions_outlined),
              ]),
            ]),
          ),
          sectionLabel(p, 'Voice & neural intelligence'),
          Glass(
            radius: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              SettingsRow(
                icon: Icons.language_rounded,
                title: 'Conversation Language',
                subtitle: app.language,
                onTap: () => showLanguageSheet(context),
              ),
              divider(),
              SettingsRow(
                icon: Icons.emoji_emotions_outlined,
                title: 'AI Persona & Voice',
                subtitle: '${app.persona} • Voice: ${app.voiceTone}',
                onTap: () => _push(context, const PersonaScreen()),
              ),
              divider(),
              SettingsRow(
                icon: Icons.volume_off_rounded,
                title: 'Silent Execution Mode',
                subtitle: 'Execute device commands without vocal reply',
                trailing: Switch(value: app.silent, onChanged: (v) => app.update(() => app.silent = v)),
              ),
            ]),
          ),
          sectionLabel(p, 'System & data engine'),
          Glass(
            radius: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              SettingsRow(
                icon: Icons.electrical_services_rounded,
                title: 'Gemini API & Model',
                subtitle: '${app.model} • REST',
                onTap: () => _push(context, const ApiScreen()),
              ),
              divider(),
              SettingsRow(
                icon: Icons.storage_rounded,
                title: 'Neural Memory Bank',
                subtitle: 'Search, review and back up learned facts',
                onTap: () => _push(context, const MemoryBankScreen()),
              ),
              divider(),
              SettingsRow(
                icon: Icons.verified_user_rounded,
                title: 'System Permissions',
                subtitle: 'Microphone, Location, Notifications & System',
                onTap: () => _push(context, const PermissionsScreen()),
              ),
              divider(),
              SettingsRow(
                icon: Icons.grid_view_rounded,
                title: 'App Control & Hands-Free',
                subtitle: 'WhatsApp, YouTube, Media & Phone shortcuts',
                onTap: () => _push(context, const AppControlScreen()),
              ),
            ]),
          ),
          sectionLabel(p, 'Appearance & security'),
          Glass(
            radius: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              SettingsRow(
                icon: Icons.palette_rounded,
                title: 'Theme & 3D Orb Colors',
                subtitle: '${app.themeName} Theme',
                onTap: () => showThemeSheet(context),
              ),
              divider(),
              SettingsRow(
                icon: Icons.shield_rounded,
                title: 'Privacy & Data Shield',
                subtitle: 'Chats stay on this device. Only AI requests go to Google (TLS).',
                onTap: () => _push(context, const PrivacyScreen()),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Center(child: Text('JARVIS INTELLIGENCE OS v1.0', style: ts(p, size: 12, w: FontWeight.w800, sub: true, spacing: 1.6))),
        ],
      ),
    );
  }
}
