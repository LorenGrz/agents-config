---
name: notebooklm-obsidian-sync
description: Use when the user wants to move knowledge between NotebookLM and Obsidian - export notebook sources to notes, save NotebookLM answers as notes, or add a note as a NotebookLM source - using the notebooklm MCP together with the obsidian MCP.
---

# NotebookLM <-> Obsidian Sync

## Setup

- NotebookLM MCP: server `notebooklm` (from `notebooklm-py`, configured in `config/mcp.user.json`). Login is manual: run `notebooklm login`.
- Obsidian MCP: server `obsidian` (`@bitbonsai/mcpvault`). Follow the `obsidian-vault` skill for conventions.
- Slugs: lowercase, hyphens, e.g. `projects/mibiblio`.

## Risk note

NotebookLM access uses unofficial APIs and Google session cookies. Use a secondary account, never `--master-token`, and tell the user if it breaks.

## Flow

### a) Inventory

`notebook_list`, then `source_list(notebook, detail=compact)`. Show titles and ids; confirm which notebook and `<project-slug>`.

### b) Export sources to Obsidian

1. For each source, `source_read(notebook, source, output_format=markdown)`; page with `offset` if `truncated`.
2. `write_note` to `projects/<project-slug>/fuentes/<source-title-slug>.md` with frontmatter: `source_id`, `notebook`, `type`, `url`, `exported` (ISO date), then the content.
3. Write or update the index note `projects/<project-slug>/fuentes.md` linking each source with `[[...]]`.
4. Re-sync: skip sources whose note exists with the same `source_id`; for URL/Drive sources check `notebooklm source stale <source_id>` and re-export only stale or new ones.

### c) Q&A to notes

`chat_ask(notebook, question)`, then `write_note` under `projects/<project-slug>/notas/<question-slug>.md` keeping the citations and source links, with `title`, `tags`, `created`, `status` frontmatter.

### d) Obsidian to NotebookLM

`read_note`, then `source_add(notebook, source_type="text", title=..., text=...)`. Confirm notebook and note first; the content leaves the machine.

## Rules

- Do not overwrite an existing note without showing the diff or getting OK.
- Never export secrets or private notes to NotebookLM.
- Report counts: exported, skipped, failed.
