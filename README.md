# 📺 StreamCast - Flutter

App para castear videos de internet a Chromecast/TV.

## Características

- 🌐 **Navegador integrado** - Detecta videos automáticamente
- 🎬 **Multi-formato** - MP4, HLS, DASH, WebM
- 📺 **Chromecast** - Envía cualquier video a tu TV
- 🎮 **Controles completos** - Play, pause, stop, seek, volume
- 🔍 **Detección inteligente** - Rankings por calidad y relevancia
- 🌙 **Tema oscuro** - UI moderna

## Formatos Soportados

- MP4 / WebM / MKV
- HLS (.m3u8)
- DASH (.mpd)

## Requisitos

- Flutter 3.x
- Android 6.0+ (API 23)
- Google Cast SDK

## Build

```bash
# Instalar dependencias
flutter pub get

# Build debug
flutter build apk --debug

# Build release (optimizado)
flutter build apk --release
```

## APK

`build/app/outputs/flutter-apk/app-release.apk`

## Dependencias

- `flutter_inappwebview`
- `google_cast_framework`
- `video_player`
- `provider`

## Uso

1. Abre la app
2. Navega a cualquier página con videos
3. Toca el FAB verde "ENVIAR"
4. Selecciona tu Chromecast/TV
5. ¡Disfruta en tu TV!

## Licencia

MIT
