# Video promo LinkedIn

Komposisi HyperFrames 1080x1080, 48,5 detik, narasi Indonesia (Gemini TTS, model `gemini-2.5-pro-preview-tts`, suara Sulafat), musik latar sintetis, rekaman layar asli dari tablet.

```bash
npx hyperframes preview    # pratinjau
npx hyperframes check      # lint + tata letak + kontras
npx hyperframes render --quality high --output renders/dracin-launcher-linkedin.mp4
```

Aset di `assets/`: `clips/` (rekaman `adb screenrecord`), `audio/narasi.mp3`, `audio/bgm.mp3`, `img/` (logo dari `art/`).
