# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that monitors the Android Downloads folder for audio recordings (11-digit MP3 files), automatically transcribes them using OpenAI's Whisper API, and displays local notifications. The app is designed for real-time audio file detection and transcription.

## Common Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run the app (development mode)
flutter run

# Run on specific device
flutter devices
flutter run -d <device_id>

# Hot reload during development: press 'r' in terminal
# Hot restart: press 'R' in terminal
```

### Building
```bash
# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release

# Build for specific platforms
flutter build ios
flutter build macos
flutter build windows
```

### Testing & Linting
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Format code
flutter format lib/
```

### Cleaning
```bash
# Clean build artifacts
flutter clean

# Clean and reinstall dependencies
flutter clean && flutter pub get
```

## Architecture

### Core Functionality Flow

1. **Permission Management** ([main.dart:92-116](lib/main.dart#L92-L116))
   - Requests notification permission (Android 13+)
   - Requests storage permissions (manageExternalStorage or storage)
   - Required before file watching can begin

2. **File System Watching** ([main.dart:130-154](lib/main.dart#L130-L154))
   - Monitors `/storage/emulated/0/Download` directory
   - Uses `Directory.watch()` with `FileSystemEvent.create` filter
   - Target pattern: `^\d{11}\.mp3$` (11-digit phone numbers)
   - Triggers notification and transcription pipeline on match

3. **Notification System** ([main.dart:62-89](lib/main.dart#L62-L89), [main.dart:157-180](lib/main.dart#L157-L180))
   - Initialized with `flutter_local_notifications` plugin
   - Uses channel ID `channel_id_1` with max importance for heads-up notifications
   - Triggers when target file is detected

4. **Audio Transcription** ([main.dart:183-224](lib/main.dart#L183-L224))
   - Sends MP3 file to OpenAI Whisper API (`whisper-1` model)
   - Uses Korean language setting (`language: 'ko'`)
   - Displays results in an AlertDialog
   - API key stored in `_apiKey` field (line 39) - **must be configured**

### Key Configuration Points

- **Target Directory**: `/storage/emulated/0/Download` (hardcoded at [main.dart:38](lib/main.dart#L38))
- **File Pattern**: 11-digit MP3 files (phone number format)
- **API Key**: Located at [main.dart:39](lib/main.dart#L39) - requires OpenAI API key
- **Android Package**: `com.example.flutter_application_2`
- **Minimum Android SDK**: Defined in `android/app/build.gradle.kts`

### Dependencies

- `permission_handler: ^11.0.0` - Runtime permission requests
- `http: ^1.6.0` - API calls to Whisper
- `flutter_local_notifications: ^20.0.0` - Local notification delivery

### Platform-Specific Notes

#### Android
- Requires `MANAGE_EXTERNAL_STORAGE` or `READ_EXTERNAL_STORAGE` permission
- Requires `POST_NOTIFICATIONS` permission (Android 13+)
- Uses Material Design 3
- Core library desugaring enabled for Java 17 compatibility

#### iOS/macOS
- Darwin notification settings configured but app primarily targets Android
- File watching on iOS would require different path and permissions approach

## Development Notes

### Testing File Detection
The FAB (Floating Action Button) creates test files matching the pattern for development testing ([main.dart:227-239](lib/main.dart#L227-L239)). Note: These fake MP3 files will fail Whisper API transcription but will trigger notifications.

### API Key Management
Before deployment, replace the placeholder API key at [main.dart:39](lib/main.dart#L39) with a valid OpenAI API key. Consider using environment variables or secure storage for production.

### File Watching Limitations
- Only monitors `FileSystemEvent.create` events
- Does not watch subdirectories (`recursive: false`)
- Pattern matching is case-sensitive
- Stream subscription is cancelled on widget disposal
