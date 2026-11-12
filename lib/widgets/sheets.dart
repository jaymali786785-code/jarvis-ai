// sheets.dart
// Shared bottom sheets: main menu, conversation language, theme picker.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/memory_service.dart';
import 'glass.dart';

Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final app = ctx.watch<AppState>();
      final p = app.palette;
      return Container(
        margin: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: Glass(
          radius: 32,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          tint: p.dark ? null : Colors.white,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Select Conversation Language', style: ts(p, size: 19, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: kLanguages
                    .map((l) => RadioListTile<String>(
                          value: l,
                          groupValue: app.language,
                          activeColor: p.accent,
                          title: Text(l, style: ts(p, w: FontWeight.w700)),
                          onChanged: (v) {
                            app.update(() => app.language = v!);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            ),
          ]),
        ),
      );
    },
  );
}

Future<void> showThemeSheet(BuildContext context) {
  final hex = TextEditingController(text: '#E10600');
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final app = ctx.watch<AppState>();
      final p = app.palette;
      const opts = {
        'Light': 'Crisp studio white - Blue & Violet accents',
        'Dark': 'Deep midnight cosmic - Neon cyan & purple',
        'Red': 'Obsidian crimson',
        'Sunset': 'Warm pastel peach',
      };
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Glass(
            radius: 32,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Text('Select App Theme', style: ts(p, size: 19, w: FontWeight.w900))),
                ...opts.entries.map((e) => RadioListTile<String>(
                      value: e.key,
                      groupValue: app.themeName,
                      activeColor: p.accent,
                      title: Text(e.key, style: ts(p, w: FontWeight.w800)),
                      subtitle: Text(e.value, style: ts(p, size: 13, sub: true)),
                      onChanged: (v) => app.update(() => app.themeName = v!),
                    )),
                RadioListTile<String>(
                  value: 'Custom',
                  groupValue: app.themeName,
                  activeColor: p.accent,
                  title: Text('Custom Background', style: ts(p, w: FontWeight.w800)),
                  onChanged: (v) => app.update(() => app.themeName = v!),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: hex,
                        style: ts(p),
                        decoration: const InputDecoration(labelText: '#RRGGBB', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        final s = hex.text.replaceAll('#', '').trim();
                        final v = int.tryParse(s, radix: 16);
                        if (s.length != 6 || v == null) {
                          snack(ctx, 'Valid hex daalo, jaise #E10600');
                          return;
                        }
                        app.update(() {
                          app.customColor = 0xFF000000 | v;
                          app.themeName = 'Custom';
                        });
                      },
                      child: const Text('Apply'),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Wrap(
                    spacing: 12,
                    children: [0xFFE10600, 0xFF2563EB, 0xFF7C3AED, 0xFF059669, 0xFFF59E0B, 0xFFEC4899]
                        .map((c) => GestureDetector(
                              onTap: () => app.update(() {
                                app.customColor = c;
                                app.themeName = 'Custom';
                              }),
                              child: CircleAvatar(radius: 16, backgroundColor: Color(c)),
                            ))
                        .toList(),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showMainMenu(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final app = ctx.read<AppState>();
      final p = app.palette;
      Widget item(IconData i, String label, VoidCallback f) => ListTile(
            leading: Icon(i, color: p.accent),
            title: Text(label, style: ts(p, w: FontWeight.w800)),
            onTap: () {
              Navigator.pop(ctx);
              f();
            },
          );
      return Container(
        margin: const EdgeInsets.all(12),
        child: Glass(
          radius: 32,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            item(Icons.home_rounded, 'Home', () => app.setTab(0)),
            item(Icons.chat_bubble_rounded, 'Chats', () => app.setTab(1)),
            item(Icons.code_rounded, 'Code Studio', () => app.setTab(4)),
            item(Icons.settings_rounded, 'Settings', () => app.setTab(3)),
            item(Icons.add_comment_rounded, 'New chat', () {
              final id = ctx.read<MemoryService>().newThread();
              app.setTab(1);
              Navigator.of(context).pushNamed('/thread', arguments: id);
            }),
          ]),
        ),
      );
    },
  );
}
