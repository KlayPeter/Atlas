---
name: atlas-readable-html
description: Rewrite Markdown or TXT into an easier-to-understand version and then produce secure HTML. Use for AI-enhanced HTML, 易读版正文, 通俗化改写, long-sentence simplification, terminology explanations, improved document flow, summaries, concepts, and study prompts while preserving facts and uncertainty.
---

# Atlas Readable HTML

Create an easy-to-read edition, not merely a summary placed above unchanged text. Keep an exact original mode available separately.

## Editing Workflow

Use the smallest intervention that makes the supplied text easier to follow.

1. **Faithful structure pass.** Identify the source's existing topic boundaries, definitions, steps, comparisons, and parallel items. Use headings, lists, tables, code blocks, and quotes only to reveal that structure. Do not add, remove, or reword material in this pass.
2. **Plain-language pass.** Rewrite only where it lowers reading effort: one topic per paragraph, shorter sentences when needed, concrete subjects and verbs, direct positive statements, parallel forms for parallel ideas, and no empty filler. Retain the original term at its first plain-language explanation.
3. **Reader-flow pass.** Check that each paragraph has a clear purpose, the transition to the next paragraph is supported by the source, and a new reader can locate the claim, evidence, and conditions. Remove generic AI phrasing, personal anecdotes, hype, and invented examples.

When the original is already clear, stop after the faithful structure pass. Structural formatting must never be used to imply a relationship the source did not establish.

## Rewrite Contract

Preserve:

- every material fact, number, name, date, condition, conclusion, citation, URL, code sample, and uncertainty marker;
- the author's position and the distinction between fact, opinion, hypothesis, and quotation;
- Markdown semantics needed for later deterministic HTML conversion.

Improve:

- split long sentences and dense paragraphs;
- replace jargon with plain language while retaining the original term on first use;
- make hidden causal, contrast, and sequence relationships explicit when supported by the source;
- add descriptive headings, short transitions, and lists where they reduce cognitive load;
- remove repetition only when no information or emphasis is lost.

Never invent facts, examples, citations, certainty, motivations, or conclusions. Never silently fix disputed claims. Do not change code, formulas, quoted text, or link targets.

Avoid a generic editorial voice: no puffery, promotional adjectives, fabricated reader reactions, or advice that the source does not give. Preserve the author's appropriate level of formality and uncertainty.

## Coverage Rules

1. Rewrite only content actually supplied.
2. For chunked documents, preserve chunk order and join all rewritten chunks.
3. Replace the original body only when every chunk is covered. If sampling was necessary, keep the original body and provide an explicitly partial guide instead.
4. Keep the rewritten body in Markdown so `atlas-markdown-to-html` performs the final safe conversion.

## Structured Output

Return one JSON object with:

- `title`, `lead`, and `summary`;
- `rewrittenMarkdown`: the complete rewritten supplied text;
- `sections`: concise reading guidance;
- `keyConcepts`: original terms with plain-language definitions;
- `questions`: comprehension questions grounded in the source.

Return no prose outside JSON. Before returning, check numbers, named entities, negation, conditions, quotations, and conclusions against the input.
