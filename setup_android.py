#!/usr/bin/env python3
"""
setup_android.py
Run AFTER `flutter create` has generated the android/ folder.
Patches AndroidManifest.xml (permissions, queries, app label) and sets minSdk 24.
Safe to run more than once.
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
manifest = root / "android/app/src/main/AndroidManifest.xml"
if not manifest.exists():
    sys.exit("android/ not found. Run: flutter create --org com.techgptx --project-name jarvis_ai --platforms=android .")

PERMS = """    <!-- jarvis_ai permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <queries>
        <intent><action android:name="android.speech.RecognitionService"/></intent>
        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
    </queries>
"""

text = manifest.read_text()
if "jarvis_ai permissions" not in text:
    text = text.replace("<application", PERMS + "    <application", 1)
text = re.sub(r'android:label="[^"]*"', 'android:label="Jarvis"', text, count=1)
manifest.write_text(text)
print("patched", manifest)

for name in ("build.gradle", "build.gradle.kts"):
    g = root / "android/app" / name
    if g.exists():
        s = g.read_text()
        s2 = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", s)
        s2 = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", s2)
        if s2 != s:
            g.write_text(s2)
            print("minSdk -> 24 in", g)
