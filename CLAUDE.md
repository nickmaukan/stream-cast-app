# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Maukan Cast** — Flutter Android app for browsing web videos and casting to Chromecast/TV via DIAL protocol. Supports MP4, HLS, DASH, WebM, YouTube, and Vimeo.

## Build Commands

```bash
# Install dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Clean and rebuild (uses Android Studio JDK)
./build-as.sh clean && ./build-as.sh
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Architecture

**Clean Architecture with Feature-first organization and BLoC state management.**

```
lib/
├── main.dart                    # Entry point, DI setup, BLoC providers
├── di/injection_container.dart  # GetIt dependency injection
├── core/
│   ├── services/                # Core infrastructure
│   │   ├── casting_engine.dart         # DIAL protocol (Chromecast)
│   │   ├── cast_discovery_service.dart # mDNS device discovery
│   │   ├── video_detector_service.dart # JS video extraction from pages
│   │   └── database_service.dart       # SQLite (history/favorites)
│   └── models/                  # Domain models
│       ├── cast_device.dart
│       ├── video_source.dart
│       └── cast_state.dart
└── features/
    ├── browser/                 # Web browser + video detection
    ├── casting/                 # Chromecast controls
    ├── history/                 # Watch history
    ├── favorites/               # Saved favorites
    └── settings/
```

**Key architecture decisions:**
- `CastingBloc` manages all casting state (discovery, connection, playback)
- `BrowserBloc` handles browser state and video detection
- `CastingEngine` implements DIAL over HTTP (not official Cast SDK)
- `CastDiscoveryService` uses mDNS to find cast devices on local network
- `VideoDetectorService` injects JavaScript into web pages to find video URLs

## Key Dependencies

- `flutter_bloc` — State management
- `flutter_inappwebview` — In-app browser with JS injection
- `go_router` — Navigation
- `sqflite` — Local database
- `dio` / `http` — HTTP client for DIAL protocol
