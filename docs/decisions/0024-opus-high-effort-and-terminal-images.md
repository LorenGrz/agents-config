# 0024 — Opus at high effort; terminal images inside tmux

Status: accepted (2026-11-10). Supersedes the medium effort of [0018](0018-opus-medium-default-reasoner-high.md)
(`model: opus` and `reasoner` at high stay).

## Context

- Effort: the owner works with Opus at high (his local `~/.claude/settings.json` already had
  `modelSettings.claude-opus-5-5.effortLevel = "high"`), but the base said medium, so every
  `install.sh` run lowered it again.
- Images: in caolg the agents run inside tmux. Claude Code asks the terminal whether it can draw
  images (kitty graphics protocol); inside tmux the answer is `tmux`, so pasted images show as
  `Image #N` with no thumbnail (`paste-preview` plugin), while straight Ghostty shows them. tmux already
  has `allow-passthrough on` and Claude Code wraps the images for tmux when forced. CAO unsets every
  `CLAUDE*` variable before launching `claude`, so exporting the variable in the shell does not reach it.

## Decision

- `config/settings.base.json`: `effortLevel` and `modelSettings.claude-opus-5-5.effortLevel` = `"high"`.
- `config/settings.base.json` `env`: `"CLAUDE_CODE_FORCE_TERMINAL_IMAGES": "1"` (settings `env` is applied
  by Claude Code itself, after CAO's unset). Tested by hand in tmux inside Ghostty: thumbnails show.

## Consequences

- Higher cost and latency per turn in the main session than at medium.
- Images are forced in every terminal, not only tmux. Fine in Ghostty/kitty; a terminal without the
  kitty graphics protocol (e.g. the VS Code terminal) would print garbage. If that happens, remove the
  variable and set it per launch instead.
- caolg sessions already open do not pick it up: close them and open a new one with `claudes`.
