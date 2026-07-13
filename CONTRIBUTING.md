# Contributing to Atlas

Thanks for helping Atlas make local Markdown and TXT easier to read and understand on a phone.

## Start with the product boundary

Atlas is a local-first reader. A contribution should strengthen this loop:

```text
Open Markdown/TXT → read comfortably → understand in context → export or share
```

Before proposing a large feature, check that it belongs in this loop. Complex editing, cloud sync, plugin systems, and heavy knowledge-base features are outside the current MVP scope.

## Report a bug or propose a feature

Search [existing issues](https://github.com/KlayPeter/Atlas/issues) first. When opening a bug, include:

- Platform, OS version, Flutter version, and Atlas commit or release.
- A minimal sample document with private content removed.
- Exact reproduction steps, expected behavior, and actual behavior.
- Relevant logs or screenshots with API keys, tokens, file paths, and personal text removed.

For a feature, describe the reading problem before the proposed UI. This makes smaller and better solutions easier to find.

## Development setup

Requirements:

- Flutter stable with Dart 3.11 or newer
- Bun 1.x
- Git
- Android Studio or Xcode for device builds

Clone the repository:

```bash
git clone https://github.com/KlayPeter/Atlas.git
cd Atlas
```

Run the Flutter app:

```bash
cd apps/atlas_app
flutter pub get
flutter run
```

Run the BFF:

```bash
cd services/atlas_bff
bun install
cp .env.example .env
bun run dev
```

Never commit `.env` files, API keys, signing keys, access tokens, or user documents.

## Architecture rules

- Keep import, parsing, rendering, progress, and original HTML export local when possible.
- Treat `services/atlas_bff` as an AI boundary, not the owner of the reading experience.
- Place features under `apps/atlas_app/lib/features/<feature>/` and separate presentation, application, and data concerns.
- Keep business rules out of widgets. Use repositories or services for data access and Riverpod for shared state.
- Preserve the unified BFF response envelope: `{ ok, data }` or `{ ok, error }`.
- Validate BFF input and environment values with Zod.
- Keep changes small. Do not refactor unrelated code in the same pull request.

## Tests and checks

Run the checks for every area you change.

Flutter:

```bash
cd apps/atlas_app
flutter analyze
flutter test
```

BFF:

```bash
cd services/atlas_bff
bun run typecheck
bun test
```

For behavior changes, add a test that fails before the fix and passes after it. For reader, import, AI, or export changes, also run the main flow in [`docs/mvp-verification.md`](docs/mvp-verification.md).

## Pull request checklist

- Explain the user problem and the smallest solution implemented.
- Link the related issue when one exists.
- Add or update tests and documentation.
- Run the relevant analyze, test, typecheck, and build commands.
- Keep generated files, build outputs, secrets, and unrelated formatting out of the commit.
- Note platform-specific behavior and any remaining limitation.

By contributing, you agree that your contribution is licensed under the repository's [MIT License](LICENSE).
