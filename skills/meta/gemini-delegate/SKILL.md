---
name: gemini-delegate
description: Use only when the user asks to use Gemini / Google / Antigravity (`agy`) for a task - delegates the work to Gemini headless (`run`) or opens an interactive `agy` session (`open`). Never start it on your own, it spends the Gemini quota.
---

# gemini-delegate

## Objective

Send a task to Gemini through the Antigravity CLI so bulk reading/generation runs on Google's quota. Gemini sees the repo and the shared skills/rules (rulesync, ADR 0002) but **not this conversation**: everything it needs goes in the spec.

## When to use

- Only when the user explicitly asks for Gemini / Google / Antigravity. Large mechanical writing or wide
  reading is not a reason by itself.

### When not to

- Architecture, security, migrations, unknown-cause bugs → `reasoner` / plan mode. Gemini executes decisions, it does not make them.
- Small changes (≤3 known files) → inline; the spec costs more than the edit.

## Workflow

1. Write the spec to a file (scratchpad or `.scratch/<topic>/…`): goal, exact files, constraints, and the acceptance command.
2. Make sure the worktree is clean (commit/stash). For big jobs prefer a git worktree.
3. Run: `~/.agents/skills/meta/gemini-delegate/scripts/gemini-delegate.sh run -f <spec.md>` (options: `--model`, `--timeout 20m`, `--allow-dirty`). It runs `agy -p … --dangerously-skip-permissions`, so the clean-worktree check is the safety net: everything Gemini did is the diff.
4. Review `git diff`, run the acceptance command yourself. If it fails, fix inline; re-run with the failure pasted into a new spec only with the user's OK, since each run spends quota. If the diff is wrong, discard it with the user's OK.
5. Report: files changed, verification command and result, anything unverified.

### Hand-off to the user

`gemini-delegate.sh open -f <spec.md>` opens an interactive `agy -i` session (tmux split if inside tmux, otherwise the default terminal) with the prompt loaded, and returns immediately. Use it when the user wants to drive Gemini themselves.

Default model: `gemini-3.8-flash-high` (`GEMINI_DELEGATE_MODEL` or `--model` to change; list with `agy models`).
