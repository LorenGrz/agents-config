---
name: debug-assistant
description: Use this skill whenever the user pastes an error message, exception, or stack trace (TypeError, undefined/null access, failing test, HTTP 500, crash) and asks why it fails or how to fix it - even when the fix looks like one line. Works from symptom to root cause to a minimal fix, with an explanation of why it failed and how to prevent it.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  triggers:
    - debug this error
    - why does this fail
    - stack trace
    - TypeError
    - undefined is not a function
    - fix this bug
---

# Debug Assistant

## Objective

Diagnose a failing piece of code: name the real cause, not the symptom, and propose the smallest change that fixes it.

## Workflow

1. Read the full error: message plus stack trace. Locate the exact failing line.
2. Inspect the context around it: variable values, types, async flow, recent changes.
3. State what the error actually means in plain language, not a restatement of the text.
4. Identify the root cause. If several are plausible, list them most-likely first.
5. Give the minimal fix as a code diff.
6. Add one prevention tip: a type, a guard, a test, a lint rule.

## Output

- **Diagnosis**: what the error means.
- **Root cause**: why it happens here.
- **Fix**: corrected code, scoped to the problem.
- **Prevention**: one concrete way to stop it recurring.

## Operating Rules

- Do not rewrite unrelated code.
- Always explain the why, not just the what.
- If the framework, runtime version, or missing context blocks diagnosis, ask for it instead of assuming.
- Prefer a fix that fails loudly next time over one that hides the problem.
- For crashes that produced a core dump on this machine, use `diagnose-crash` instead.
