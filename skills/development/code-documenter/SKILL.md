---
name: code-documenter
description: Use this skill when writing reference documentation for an existing function, class, or module - producing a description, typed parameters, return type, runnable usage examples, and edge cases in the language's native doc format.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  stack:
    - typescript
    - javascript
    - python
  triggers:
    - document this function
    - write docstrings
    - JSDoc
    - TSDoc
    - API docs
    - explain what this code does
---

# Code Documenter

## Objective

Turn undocumented code into accurate reference docs in the format the language expects: TSDoc/JSDoc for TypeScript and JavaScript, docstrings for Python, KDoc for Kotlin, Javadoc for Java.

## Workflow

1. Read the whole unit: signature, body, control flow, thrown errors, external calls.
2. Describe what it does in one sentence that does not just restate the name.
3. List every parameter with its type, whether it is optional, and its default.
4. Document the return type and what each variant means for union or result types.
5. Write at least two runnable examples: the normal case and one special case.
6. List edge cases the caller must handle: null or undefined input, empty arrays, out-of-range values, unexpected types, thrown errors.
7. If numeric or unit assumptions exist (milliseconds, 0-based index, currency), state them.

## Output

- A doc block in the language's native format, placed directly above the unit.
- A short usage-examples section.
- A notes section for edge cases and limitations.

## Operating Rules

- Do not document behavior that is not in the code. If intent is unclear, say so instead of guessing.
- Do not restate the obvious ("returns a boolean").
- Every parameter needs a type and a reason to exist in the docs.
- Examples must run without modification against the real signature.
- Match the surrounding file's existing doc style and comment density.
- For deeper TypeScript typing concerns, defer to `typescript-code-quality`.
