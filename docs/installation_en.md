# Download and install Atlas

**English** · [简体中文](installation.md)

## Release status

Atlas has a verified local Android release-APK build, but [GitHub Releases](https://github.com/KlayPeter/Atlas/releases) does not yet contain the first public, production-signed package.

- To try Atlas now, build the Android APK from source below.
- To wait for a signed package, Watch or Star the repository and follow the Releases page.
- iOS source builds run today. The native Share Extension remains unfinished, and no TestFlight or App Store package is available.

## Android: build from source

### Requirements

- Flutter stable with Dart 3.11 or newer
- Android Studio, Android SDK, and Java 17
- An Android device or emulator

### Build the APK

```bash
git clone https://github.com/KlayPeter/Atlas.git
cd Atlas/apps/atlas_app
flutter pub get
flutter analyze
flutter build apk --release
```

Output:

```text
apps/atlas_app/build/app/outputs/flutter-apk/app-release.apk
```

Install over USB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> The current `android/app/build.gradle.kts` signs release builds with the debug key for local testing. Do not treat it as a production signature. Configure a dedicated keystore before public distribution or store submission, and keep signing material private.

## iOS: run from source

### Requirements

- macOS with a current stable Xcode
- Flutter stable
- An Apple Development signing identity

```bash
git clone https://github.com/KlayPeter/Atlas.git
cd Atlas/apps/atlas_app
flutter pub get
open ios/Runner.xcworkspace
```

Choose a Team and Bundle Identifier in Xcode, then run on a simulator or device. The main iOS app runs, but importing through the system share sheet still requires the native Share Extension.

## Configure your own AI model

Atlas reads, searches, saves progress, and exports original HTML without AI. For explanation, translation, summaries, Q&A, study mode, and readable AI HTML, open **Settings → AI model** and configure your own provider.

- **API key**: issued by your model provider.
- **Base URL**: its OpenAI-compatible Chat Completions API address, usually ending in `/v1`.
- **Model name**: a model available to that key.

Atlas stores the API key in the platform secure store. AI requests travel directly from the device to the provider you entered; they do not use an Atlas server. Non-loopback Base URLs must use HTTPS.

`services/atlas_bff` remains an optional component for developers who want to study or extend it. The current app does not require a BFF.

## Verify the installation

1. Open Atlas and import `docs/samples/mvp-markdown.md` from the repository.
2. Check the outline, full-text search, code blocks, tables, and Mermaid rendering.
3. Scroll, leave, and reopen the document to confirm progress restoration.
4. Preview and share original HTML.
5. After configuring your own AI model, verify explanation, summary, Q&A, and study mode.

See [`mvp-verification.md`](mvp-verification.md) for the complete flow.
