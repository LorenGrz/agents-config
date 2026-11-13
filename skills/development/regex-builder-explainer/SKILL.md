---
name: regex-builder-explainer
description: Use this skill to build a regular expression from a natural-language description, or to explain an existing one - with a component-by-component breakdown, matching and non-matching examples, and the target engine noted.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  engines:
    - javascript
    - python
    - pcre
    - go
  triggers:
    - write a regex
    - regular expression for
    - explain this regex
    - validate string pattern
---

# Regex Builder & Explainer

## Objective

Translate a validation or extraction need into a working, readable regex, and explain every part. Also works in reverse: take a regex and explain it.

## Workflow

1. Pin down exactly what must match and what must not.
2. Confirm the engine or flavor: JavaScript, Python `re`, PCRE, Go `regexp`. Syntax and features differ.
3. Build the pattern progressively, simplest form first.
4. Break it down: every group, quantifier, anchor, character class, and metacharacter.
5. Give 3 strings that match and 2 that do not.
6. State any required flags (`g`, `i`, `m`, `s`, `u`).

## Output

- The full regex.
- A part-by-part table with plain-language meaning.
- Match / no-match examples.
- Engine and flags used, plus what the pattern deliberately does not cover.

## Operating Rules

- Readability over cleverness. Prefer an explicit pattern to a dense one.
- Avoid lookahead/lookbehind unless the task genuinely needs it, and note when the target engine lacks support.
- Anchor patterns (`^`, `$`) when validating a whole string.
- Never claim a regex fully validates emails, URLs, or dates; state the limits.
