# Atlas MVP Sample

Atlas is a local-first reader for Markdown and TXT files. The first promise is simple: when a document arrives on a phone, it should open into a quiet reading surface instead of a cramped preview.

## Local-first Reading

The app copies imported files into its private sandbox, computes a hash, and keeps recent reading progress locally. The Bun service is an AI BFF, not the owner of the reading loop.

Key goals:

- Open Markdown and TXT files.
- Preserve a recent reading list.
- Restore reading position.
- Keep AI actions tied to the current document.

## Markdown Coverage

Atlas should render common Markdown elements well enough for daily documents.

> A reader should help the user stay inside the article, not fight the interface.

```dart
void main() {
  runApp(const AtlasApp());
}
```

| Feature | MVP expectation |
| --- | --- |
| Headings | Table of contents |
| Lists | Clear indentation |
| Code | Readable block style |
| Tables | Horizontally scrollable in HTML |

## AI Context

AI requests include the document title, outline, excerpt, and selected text or question. If the document does not contain the answer, the assistant should say so instead of pretending.
