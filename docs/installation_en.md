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

## Connect a self-hosted AI backend

Atlas reads, searches, saves progress, and exports original HTML without AI. Connect Atlas BFF only when you want explanation, translation, summaries, Q&A, study mode, or readable AI HTML.

### Start BFF locally

```bash
cd Atlas/services/atlas_bff
bun install
cp .env.example .env
bun run typecheck
bun run start
```

Edit `.env`:

```dotenv
APP_ENV=development
HOST=127.0.0.1
PORT=8787
OPENAI_API_KEY=your-api-key
OPENAI_MODEL=gpt-4.1-mini
```

Enter the BFF address under **Settings → Custom AI configuration**. An Android emulator usually uses `http://10.0.2.2:8787`; the iOS Simulator usually uses `http://127.0.0.1:8787`.

### Production requirements

- Expose BFF over HTTPS.
- Set `APP_ENV=production`.
- Set `OPENAI_API_KEY`.
- Generate an `ATLAS_BFF_ACCESS_TOKEN` of at least 32 characters and enter the same value in the app.
- If clients may provide an OpenAI-compatible base URL, list allowed origins in `AI_PROVIDER_BASE_URL_ALLOWLIST`, separated by commas.
- Do not log request bodies in the reverse proxy or application logs.

## Verify the installation

1. Open Atlas and import `docs/samples/mvp-markdown.md` from the repository.
2. Check the outline, full-text search, code blocks, tables, and Mermaid rendering.
3. Scroll, leave, and reopen the document to confirm progress restoration.
4. Preview and share original HTML.
5. After configuring BFF, verify explanation, summary, Q&A, and study mode.

See [`mvp-verification.md`](mvp-verification.md) for the complete flow.
