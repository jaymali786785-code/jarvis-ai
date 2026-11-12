// commands.dart
// Local (offline) voice commands that run real Android actions without AI:
// time/date, open YouTube/WhatsApp/camera/settings, dial, google search.
// Also detects "build me a website/app" requests to route to the Code screen.

import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

class Commands {
  static bool isCodeRequest(String raw) {
    final t = raw.toLowerCase();
    final verb = RegExp(r'(banao|bana do|bana de|banana|build|create|make|develop|code likh|coding)').hasMatch(t);
    final noun = RegExp(r'(website|web site|app|todo|portfolio|landing|page|game|calculator|code|script|dashboard|tool)').hasMatch(t);
    return verb && noun;
  }

  static bool isRecallRequest(String raw) {
    final t = raw.toLowerCase();
    return RegExp(r'(kal maine|pehle maine|maine kya bola|yaad hai|yaad kar|remember|recall|did i say|what did i)').hasMatch(t);
  }

  static Future<void> _view(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Returns a spoken reply if the command was handled locally, else null.
  static Future<String?> tryLocal(String raw) async {
    final t = raw.toLowerCase().trim();
    final open = RegExp(r'(open|kholo|khol do|khol|chalao|start|launch)').hasMatch(t);

    if (RegExp(r'(what time|time kya|kitne baje|samay kya|abhi time|current time)').hasMatch(t)) {
      final n = DateTime.now();
      final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
      return 'Abhi ${h}:${n.minute.toString().padLeft(2, '0')} ${n.hour >= 12 ? 'PM' : 'AM'} ho rahe hain.';
    }
    if (RegExp(r"(today's date|aaj ki date|aaj kaun sa din|tareekh|what is the date|date kya)").hasMatch(t)) {
      final n = DateTime.now();
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return 'Aaj ${days[n.weekday - 1]} hai, ${n.day}/${n.month}/${n.year}.';
    }
    if (open && t.contains('youtube')) {
      await _view('https://www.youtube.com');
      return 'YouTube khol raha hoon.';
    }
    if (open && t.contains('whatsapp')) {
      await _view('https://wa.me/');
      return 'WhatsApp khol raha hoon.';
    }
    if (open && (t.contains('camera'))) {
      if (Platform.isAndroid) {
        await const AndroidIntent(action: 'android.media.action.STILL_IMAGE_CAMERA').launch();
        return 'Camera khol raha hoon.';
      }
    }
    if (open && t.contains('settings')) {
      if (Platform.isAndroid) {
        await const AndroidIntent(action: 'android.settings.SETTINGS').launch();
        return 'Phone settings khol raha hoon.';
      }
    }
    if (open && t.contains('bluetooth')) {
      if (Platform.isAndroid) {
        await const AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS').launch();
        return 'Bluetooth settings khol raha hoon.';
      }
    }
    if (open && (t.contains('wifi') || t.contains('wi-fi'))) {
      if (Platform.isAndroid) {
        await const AndroidIntent(action: 'android.settings.WIFI_SETTINGS').launch();
        return 'Wi-Fi settings khol raha hoon.';
      }
    }
    final call = RegExp(r'(call|dial|phone laga)\s*(?:karo|kar do|to)?\s*([+0-9][0-9 ]{5,})').firstMatch(t);
    if (call != null) {
      final number = call.group(2)!.replaceAll(' ', '');
      await launchUrl(Uri.parse('tel:$number'));
      return '$number dial kar raha hoon.';
    }
    final search = RegExp(r'^(?:search|google|dhundo|search karo)\s+(.+)$').firstMatch(t);
    if (search != null) {
      await _view('https://www.google.com/search?q=${Uri.encodeQueryComponent(search.group(1)!)}');
      return 'Search kar raha hoon.';
    }
    return null;
  }
}
