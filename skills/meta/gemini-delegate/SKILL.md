---
name: gemini-delegate
description: Use when the user asks to use Gemini / Google / Antigravity (`agy`), to save Anthropic tokens, or when a task is large mechanical writing (boilerplate, bulk tests, an already-decided refactor) or reading a lot of context. Delegates the work to Gemini headless (`run`) or opens an interactive `agy` session (`open`).
---

# gemini-delegate

Sends a task to Gemini through the Antigravity CLI so the volume of reading/generation runs on Google's quota instead of Anthropic's. Gemini sees the repo and the shared skills/rules (rulesync, ADR 0002) but **not this conversation** — everything it needs must be in the spec.

## When to use

- Large mechanical writing from an already-decided plan, bulk tests/boilerplate, wide read-and-summarize passes.
- The user explicitly asks for Gemini / Google / Antigravity.

## When not to

- Architecture, security, migrations, unknown-cause bugs → `reasoner` / plan mode. Gemini executes decisions, it does not make them.
- Small changes (≤3 known files) → inline; the spec costs more than the edit.

## Flow

1. Write the spec to a file (scratchpad or `docs/superpowers/plans/…`): goal, exact files, constraints, and the acceptance command. Gemini has no other context.
2. Make sure the worktree is clean (commit/stash). For big jobs prefer a git worktree.
3. Run: `~/.agents/skills/meta/gemini-delegate/scripts/gemini-delegate.sh run -f <spec.md>` (options: `--model`, `--timeout 20m`, `--allow-dirty`). It runs `agy -p … --dangerously-skip-permissions`, so the clean-worktree check is the safety net: everything Gemini did is the diff.
4. Review `git diff`, run the acceptance command yourself. If it fails, fix inline or re-run with the failure pasted into a new spec. If the diff is wrong, discard it with the user's OK.
5. Report: files changed, verification command and result, anything unverified.

## Hand-off to the user

`gemini-delegate.sh open -f <spec.md>` opens an interactive `agy -i` session (tmux split if inside tmux, otherwise the default terminal) with the prompt loaded, and returns immediately. Use it when the user wants to drive Gemini themselves.

Default model: `gemini-3.8-flash-high` (`GEMINI_DELEGATE_MODEL` or `--model` to change; list with `agy models`).
