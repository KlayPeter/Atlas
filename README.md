# Atlas

Atlas is a mobile-first Markdown / TXT reading app. It focuses on opening local text files quickly, rendering them beautifully on phones, and using document-aware AI to explain, summarize, question, and convert content into readable HTML.

## Repository Layout

```text
apps/
  atlas_app/        Flutter mobile app
services/
  atlas_bff/        Bun + Hono AI BFF
docs/               Product, architecture, roadmap, and issue planning
```

## Current Phase

Stage A: project skeleton and infrastructure.

- Flutter app starts at the recent reading shell.
- App routing uses `go_router`.
- Shared app state uses `flutter_riverpod`.
- The first Material 3 theme and reading-tool UI anchors are in place.
- Bun BFF exposes `GET /health` with unified success/error responses.

## Local Commands

Flutter app:

```sh
cd apps/atlas_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Bun BFF:

```sh
cd services/atlas_bff
bun install
bun run typecheck
bun run dev
```

Health check:

```sh
curl http://localhost:8787/health
```

## Product Direction

Atlas is not a heavy knowledge base or a writing-first Markdown editor. MVP work should stay anchored to one flow:

```text
Open Markdown/TXT -> read comfortably -> understand with context-aware AI -> convert/share as HTML
```

See `docs/dev-plan.md` and `docs/technical-architecture.md` for the staged plan.
