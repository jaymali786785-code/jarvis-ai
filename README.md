# Jarvis AI (Flutter)

Liquid-glass personal AI assistant: voice-reactive golden orb, Gemini chat + voice,
on-device memory, live weather, and a Code Studio with live HTML preview and auto-fix.

## APK kaise banayein (Termux se, bina Flutter install kiye)

Flutter SDK Termux par officially nahi chalta, isliye build GitHub ke free server par hota hai.

1. GitHub par free account banao, ek naya **empty repo** banao (jaise `jarvis_ai`).
2. Termux me:
   ```bash
   pkg update -y && pkg install -y git unzip
   termux-setup-storage
   cd ~ && unzip /sdcard/Download/jarvis_ai.zip && cd jarvis_ai
   git init && git add . && git commit -m "Jarvis"
   git branch -M main
   git remote add origin https://github.com/<USERNAME>/jarvis_ai.git
   git push -u origin main
   ```
   (Password ki jagah GitHub **Personal Access Token** daalna: Settings > Developer settings > Tokens, scope `repo` + `workflow`.)
3. Repo ke **Actions** tab me "Build Jarvis APK" chalega (~8-12 min).
4. Run complete hone par **Artifacts > Jarvis-APK** download karo, `app-release.apk` install karo.

## Pehli baar app me
- Settings > Gemini API & Model > free key daalo ([aistudio.google.com/apikey](https://aistudio.google.com/apikey)) > Save.
- Settings > System Permissions > GRANT ALL.
- Home par orb ya mic pill tap karke bolo.

## Kya real me kaam karta hai
- Voice: speech_to_text -> Gemini -> flutter_tts, orb mic level ke hisaab se react karta hai
- Chat threads + memory (on-device), "kal maine kya bola tha..." recall
- Weather: GPS + Open-Meteo, har 10 min refresh
- Code Studio: prompt -> real HTML/CSS/JS (ya koi aur language) -> live WebView preview, JS error par "Fix karun?"
- Local commands: time/date, YouTube/WhatsApp/camera/settings kholna, dial, Google search
- Themes, persona, language, silent mode, permissions screen

## Jo is version me nahi hai (native Android code chahiye)
- "Jarvis" wake word jo hamesha background/lock screen par sune
- Owner voice biometrics (speaker verification)
- Floating overlay orb
- Dusri apps ke andar tap/type karna (AccessibilityService)
- In-app "Build APK" (phone par Android toolchain nahi chalti)
- Gemini Live WebSocket streaming (abhi REST + TTS)

## Agar build fail ho
Actions log ka error copy karke bhej do, fix kar dunga.
