# 0021 — Statusline cache files are an interface for caolg

Status: accepted (2026-11-09)

## Context

`config/hooks/statusline.sh` receives Claude Code's statusline JSON on every refresh. Besides drawing the line it
writes two small cache files that caolg (a separate repo) reads: the quota bar (`bin/cao-usage`,
`lib/caolg_lib.py`) and the border of each agent with its context percentage and current folder
(`bin/caolg-watch`). Nothing said so, and nothing in caolg names agents-config: changing the statusline would
degrade the bar and the borders without any error.

## Decision

The two files are a contract. `statusline.sh` documents it in its header; this ADR is the reference.

| File | Written when | Fields |
|---|---|---|
| `${XDG_CACHE_HOME:-~/.cache}/claude/rate-limits.json` | the input has `rate_limits.five_hour` or `.seven_day` | `ts` (epoch, float), `rate_limits` (the input object as received: `five_hour` and `seven_day`, each with `used_percentage` and `resets_at`) |
| `${XDG_CACHE_HOME:-~/.cache}/claude/ctx/<CAO_TERMINAL_ID>.json` | `CAO_TERMINAL_ID` is set and `used_percentage` is known | `ts` (epoch, integer), `used_percentage`, `size` (context window), `cwd` (`workspace.current_dir`, else `cwd`; follows the agent's `cd`) |

- Both are written atomically (`.tmp` then `mv`) and never contain tokens or credentials.
- Fields may be added. A rename or removal is a breaking change: update caolg in the same change and say so in
  the commit.
- The rate limits belong to the account, not to the session: the last writer wins.
- caolg keeps working without the files, with a fallback (transcripts, Codex rollouts, `gh`), only less exact.

## Consequences

- The file shapes are not covered by a test in this repo yet (the writer needs a statusline JSON sample);
  caolg's tests cover its own parsing.
- Replacing the statusline script means keeping these two writes.
