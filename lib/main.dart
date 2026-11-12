// main.dart
// Entry point: loads settings + memory, wires providers, themes the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'screens/shell.dart';
import 'services/memory_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  final app = AppState();
  await app.load();
  final mem = MemoryService();
  await mem.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider.value(value: mem),
    ],
    child: const JarvisApp(),
  ));
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.palette;
    return MaterialApp(
      title: 'Jarvis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: p.dark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: p.accent,
        scaffoldBackgroundColor: p.bgTop,
      ),
      home: const Shell(),
      onGenerateRoute: (s) {
        if (s.name == '/thread') {
          return MaterialPageRoute(builder: (_) => ThreadScreen(threadId: s.arguments as String));
        }
        return null;
      },
    );
  }
}
