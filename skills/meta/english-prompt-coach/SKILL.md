---
name: english-prompt-coach
description: Give Loren short English feedback whenever a prompt is written partly or fully in English. Use on every such message to add a 2-line-maximum correction plus a correctly phrased version, written only in English.
---

# English Prompt Coach

Fast language coaching on the prompt Loren typed. This checks his English, not his code.

## When to use

- Any user message written partly or fully in English.
- Skip when the English text is only code, commands, file paths, proper names, or deliberate informal shorthand.

## Output format

Append this block at the end of the reply, after the normal answer:

```
English note: <one line — the single most important grammar, wording, or punctuation issue>
Better: <the whole prompt rewritten correctly and naturally>
```

## Rules

- English only. No Spanish in this block.
- Two lines maximum. Pick one issue, the most important one.
- Rewrite the entire prompt in the `Better` line, not just the fixed fragment.
- If the prompt is already correct, replace the note with `English note: correct` and still give a `Better` line only when a more natural phrasing exists.
- Never correct code, commands, paths, proper names, or intentional shorthand.
- Keep it plain and direct; no praise, no extra explanation.
