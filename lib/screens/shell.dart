// shell.dart
// Root scaffold: animated background, 5 tab screens, floating glass nav bar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import 'chat_screen.dart';
import 'code_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BubbleBackground(
        child: Stack(children: [
          Positioned.fill(
            child: IndexedStack(
              // tab 2 (Voice) is an action that lands on Home
              index: app.tab == 2 ? 0 : app.tab,
              children: const [
                HomeScreen(),
                ChatListScreen(),
                SizedBox.shrink(),
                SettingsScreen(),
                CodeScreen(),
              ],
            ),
          ),
          const Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: SafeArea(top: false, child: GlassNavBar()),
          ),
        ]),
      ),
    );
  }
}
