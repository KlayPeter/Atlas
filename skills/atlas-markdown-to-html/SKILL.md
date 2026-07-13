---
name: atlas-markdown-to-html
description: Convert Markdown or TXT into secure, faithful, long-form HTML for Atlas. Use for md-to-html export, local HTML previews, reader-friendly typography, tables, code, headings, links, images, Mermaid fallbacks, or HTML conversion tests where source meaning must not be rewritten.
---

# Atlas Markdown to HTML

Convert deterministically and locally. Preserve source wording and document order; use `atlas-readable-html` when rewriting is requested.

## Workflow

1. Parse Markdown with GitHub-flavored extensions; escape TXT as paragraphs.
2. Preserve headings, lists, blockquotes, tables, links, code fences, inline code, and alt text.
3. Generate stable heading IDs and a linked table of contents.
4. Render Mermaid locally when a trusted native renderer exists; otherwise keep a visible fenced-code fallback. Never fetch executable code from a CDN.
5. Apply quiet long-form typography: 16–18px body text, 1.7–1.9 line height, 680–780px measure, responsive padding, horizontal scrolling for tables and code.
6. Emit a complete UTF-8 HTML document and validate it.

## Security Rules

- Escape raw HTML and every AI-provided field before insertion.
- Use a restrictive CSP: deny scripts, frames, objects, forms, connections, and base URL changes.
- Disable JavaScript in previews.
- Permit only safe link schemes; add `noopener noreferrer` to external links.
- Do not load remote images automatically. Permit validated embedded raster data only, or require explicit user consent outside exported HTML.
- Do not expose arbitrary local file paths.

## Verification

- Test headings and TOC anchors, raw-HTML escaping, unsafe links and images, tables, code blocks, CJK text, dark mode, and narrow screens.
- Confirm original mode performs no AI or network request.
- Confirm conversion failures replace loading state with a visible error.
