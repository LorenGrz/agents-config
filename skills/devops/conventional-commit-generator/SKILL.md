---
name: conventional-commit-generator
description: Use this skill to turn a diff or a description of changes into commit messages that follow Conventional Commits - inferring type and scope, writing an imperative subject, and splitting unrelated changes into separate commits.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  triggers:
    - write a commit message
    - conventional commit
    - commit these changes
    - changelog entry
---

# Conventional Commit Generator

## Objective

Produce commit messages in `type(scope): description` form so history stays readable and changelog-friendly.

## Workflow

1. Read the actual change: `git diff --staged`, a diff, or a written description.
2. Pick the type: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `build`, `ci`.
3. Infer a scope from the affected area (`auth`, `api`, `ui`, `db`, module name). Omit if it spans everything.
4. Write the subject in the imperative, lowercase, no trailing period, at most 72 characters.
5. Add a body only when the reason for the change is not obvious from the diff.
6. If changes are unrelated, propose separate commits.
7. Mark breaking changes with a `BREAKING CHANGE:` footer.

## Output

```
type(scope): imperative subject under 72 chars

Optional body explaining why, wrapped at ~72 columns.

BREAKING CHANGE: description, if any.
```

## Operating Rules

- Imperative mood: "add", not "added" or "adds".
- One commit is one logical change; never mix `feat` and `fix`.
- Do not invent a scope or motive; ask if the type is ambiguous.
- Keep any trailers a repo or workflow requires (e.g. `Co-Authored-By`, sign-off) below the body.
- Follow the repo's existing commit style if it diverges from this.
