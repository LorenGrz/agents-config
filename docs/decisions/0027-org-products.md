# 0027 — Organizations with products

Status: accepted (2026-11-13). Builds on ADR 0012 (organizations) and 0026 (self-sufficient org repos).

## Context

An organization can run several product lines with different stacks and different teams. Its repo kept
every skill in one flat `skills/` folder, so a project of one product received the other product's skills
too, and a teammate installing the org as a plugin got everything at once. Splitting the org into two
repos would duplicate the shared policies and the tool skills (GitHub, tracker, chat) and let them drift.

## Decision

- **`products` in `org.json`** (optional): `{"<product>": {"remote_patterns": [regex, ...]}}`. With it, each
  product has its own folder `<product>/` with `skills/`, `commands/` and a full `POLICIES.md`. The root
  `POLICIES.md` stays: it is the org-wide core that the global index and `~/.claude` import.
- **`orgs.sh validate`** checks each product folder (exists, has `POLICIES.md`, skills and commands well
  formed, no baseline weakening) and accepts a `replaces` target that exists in any product.
- **`project-agents.sh`** takes `--product <name>`, or picks the product whose patterns match the project's
  `origin` (in a workspace folder, its child repos). No single match fails closed with the list of
  products. Everything else (stack filters, `replaces`, index and critical rows) works on the chosen
  product as it did on the org root.
- How an org keeps the copies of its shared skills in step across products is the org repo's business (a
  sync script with a `--check` is the expected shape); the hub reads only the product folders.
- The POLICIES template of ADR 0026 applies to each product's `POLICIES.md`; the root one has the summary,
  the core and the project section, without product sections.

## Consequences

- An org without `products` works exactly as before.
- A project or workspace whose remotes match no product (or several) must pass `--product`.
- `.agents/skills.lock` records the org name and version, not the product; the installed files show which
  product it is.
