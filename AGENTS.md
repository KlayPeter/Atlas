# AGENTS.md

## Project

Atlas is a local-first Flutter reader for Markdown and TXT files, with a Bun/Hono backend for AI-assisted explanation, summarization, Q&A, and later enhanced HTML export.

## Architecture Rules

- Keep reading local-first. The app should parse, render, store recent files, restore progress, and perform faithful HTML conversion locally whenever possible.
- Treat the Bun service as an AI BFF, not as the owner of the reading experience.
- Keep features under `apps/atlas_app/lib/features/<feature>/` with clear `presentation`, `application`, and later `data` boundaries.
- Keep cross-feature models in `apps/atlas_app/lib/domain/` only when they are genuinely shared.
- Use repositories/services for data access. Widgets should contain layout and event wiring, not business rules.
- Use Riverpod for shared app state and dependency wiring. Local ephemeral UI state can stay inside widgets.
- Use `go_router` for app routes and future deep links.
- Use Material 3 and quiet reading-tool UI. Avoid marketing-page layouts inside the app.
- Backend routes should return the unified `{ ok, data }` / `{ ok, error }` envelope.
- Validate backend inputs and environment with Zod.

## Stage Order

1. Stage A: Flutter and Bun skeletons, routing, theme, lint/test baseline.
2. Stage B: local file import, SQLite/Drift, Markdown/TXT parsing, reader, recent reading, progress.
3. Stage C: AI selection explanation, summary, Q&A, streaming response, cache.
4. Stage D: faithful local HTML conversion, preview, export/share.
5. Stage E: AI-enhanced HTML and study mode.

## Commands

Flutter:

```sh
cd apps/atlas_app
flutter analyze
flutter test
```

Bun:

```sh
cd services/atlas_bff
bun run typecheck
bun run dev
```

## Collaboration Notes

- Read `docs/` before changing product scope or architecture.
- Preserve the Atlas name in docs, package names, route examples, and service paths.
- Do not commit secrets or local `.env` files.
- Keep MVP focused: no complex editor, sync system, plugin system, or heavy knowledge-base features until the reading loop works.
