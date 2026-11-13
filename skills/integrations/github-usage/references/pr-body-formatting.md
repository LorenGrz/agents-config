# PR body formatting

Read when: writing or editing a PR body that needs diagrams, alerts, collapsibles, tables or images.

How a PR body looks on GitHub (markup only). `mattpocock-skills:pr` covers what goes in the summary:
the smallest view that explains the change (pseudocode, call tree, file tree, Mermaid, `diff` blocks).

- **Diagrams only for verified facts**, as a ` ```mermaid ` block (GitHub renders it in PRs, issues
  and `.md`). Pick by change: flow or topology → `flowchart`; call order → `sequenceDiagram`; states →
  `stateDiagram-v2`; schema → `erDiagram`. A small fix needs none.
- **Alerts** for the one thing that must not be missed: `> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`,
  `[!WARNING]`, `[!CAUTION]`, every line prefixed with `> `. One or two per body, never back to back,
  never nested.
- **Collapsibles** for long logs or output: `<details><summary>Text</summary>` with a blank line
  after `</summary>` and before `</details>` so the Markdown inside renders. Never hide anything that
  decides whether the PR is ready, and never put screenshots inside.
- **Tables** need a blank line before them and `---` per column; escape a `|` inside a cell as `\|`.
- **Images:** keep native resolution and size them in HTML, `<img src="URL" width="600" alt="...">`
  (inside a before/after table, the same `width` on both sides). Same viewport and crop before and
  after. One or two lines of caption per image. Uploads: 10 MB per image or GIF. Dark-mode variants via
  `<picture><source media="(prefers-color-scheme: dark)" srcset="..."><img src="..."></picture>`.
- GitHub strips `<script>`, inline `style`, `class` and `id`: no custom CSS. `<!-- -->` stays hidden.

Sources: docs.github.com "Creating diagrams", "Basic writing and formatting syntax", "Organizing
information with collapsed sections", "Organizing information with tables", "Attaching files";
ideas from `hyperb1iss/hyperskills` `super-good-pr` and `github/awesome-copilot` `pr-screenshots` (MIT).
