# Plan: agents-config como fuente de verdad de integraciones (Slack, Jira, GitHub, Google, NotebookLM, Codex, Obsidian)

## Context
Hoy agents-config versiona skills, hooks, rules y settings, pero no lo instalado en esta sesión
(paste-preview + parche, skill-creator, github) ni lo que se va a instalar. Además `install.sh` no maneja
MCP de usuario y, re-ejecutado, apagaría vercel (base `false`, live `true`). Loren quiere que agents-config
declare MCPs + skills + hooks + rules para usar bien Slack, Jira, GitHub, NotebookLM, Codex, Obsidian y
Google (Calendar, Gmail, Drive), y que todo quede documentado en Obsidian. También: plan de MiBiblio
(hoy en NotebookLM) en el vault, `projects/mibiblio/`.

Ya hecho: parche paste-preview (editor no se abre al pegar), repo privado `LorenGrz/MiBiblio`,
carpeta `projects/mibiblio` en `~/Documents/Obsidian Vault`. Clones de referencia en `~/resources`.
Fuera de alcance: n8n, impeccable, higgsfield; Graphify "por ahora nada".

## Decisiones (ADR 0016 `docs/decisions/0016-integrations-plugins-mcp.md`)
- **Conectores de cuenta claude.ai** (Slack, Atlassian/Jira, GitHub, Gmail, Calendar, Drive) ya están
  activos a nivel cuenta: no se declaran en archivos; agents-config aporta skills de uso + guardrails.
- **MCP de usuario** (globales, personales): NotebookLM y Obsidian (+ `cao-mcp-server` existente) en
  nuevo `config/mcp.user.json`. Excepción documentada a la política "MCP opt-in por repo" (README:317).
- **Plugins** declarados en `config/settings.base.json` (`enabledPlugins` + `extraKnownMarketplaces`).
- **Plugin `github`**: hoy falla (auth header mal formado) y duplica el conector claude.ai GitHub + `gh`
  → deshabilitarlo (recomendado) en vez de configurar un PAT.
- **vercel**: alinear base con live (`true`) o dejar `false` — se mantiene `false` por política de
  tokens salvo que Loren diga lo contrario en la aprobación.

## Pasos
1. **Auditar** plugins nuevos desde `~/resources` (hooks.json, scripts, red) antes de declararlos:
   mattpocock/skills, claudex-loop, codex-plugin-cc (sin review gate), claude-obsidian (hooks
   SessionStart/Stop de `scripts/claude-obsidian.py`), andrej-karpathy-skills.
2. **Plugins** → `config/settings.base.json`: agregar skill-creator, paste-preview, mattpocock-skills,
   claudex-loop, codex, claude-obsidian, andrej-karpathy-skills con sus marketplaces; `github` → false.
   Regenerar con `scripts/gen-plugin.sh`.
3. **Parche paste-preview reproducible**: `config/patches/paste-preview-no-autoedit.sh` (idempotente,
   comenta la línea `enqueue` en cache + marketplace) invocado por `install.sh` tras instalar plugins.
4. **MCP de usuario**: `config/mcp.user.json` + paso en `install.sh` que hace
   `claude mcp add-json --scope user <name> <json>` si no existe (idempotente, sin secretos).
   - NotebookLM: `uv tool install "notebooklm-py[browser,mcp]"` (lo instala install.sh si falta uv tool);
     login manual `! notebooklm login` (cuenta que tiene el notebook, sin `--master-token`).
   - Obsidian: elegir (scout/web) un MCP mantenido que lea el vault por filesystem, auditarlo, ruta del
     vault tomada del profile (`config/profiles/loren.md`, nueva línea "Obsidian vault").
5. **Skills** nuevas en `productivity/` (globales; descripciones con triggers para auto-activarse):
   - `slack-usage`: leer/buscar libre; enviar solo con texto aprobado; draft por defecto.
   - `jira-usage`: genérico (JQL, comentar, transicionar con OK); las skills de cada organización viven en su repo privado.
   - `github-usage`: `gh` para repo local, conector claude.ai para PRs/issues remotos; reglas de org.
   - `google-workspace-usage`: Gmail (draft antes de enviar), Calendar (confirmar invitados), Drive.
   - `notebooklm`: wrapper de la skill oficial + **export NotebookLM → Obsidian** (una nota por fuente
     en `projects/<proyecto>/fuentes/`, re-ejecutable con `source stale`) y Obsidian → fuente.
   - `obsidian-vault`: convenciones del vault (`projects/<slug>/`, minúsculas, índice por proyecto),
     cuándo usar MCP vs claude-obsidian.
   - `codex-review`: cuándo `/codex:review` / `adversarial-review`, nunca review gate.
   Registrar en `config/CLAUDE.md` (Routing) y correr `./sync.sh`.
6. **Guardrails (permisos)**: en `settings.base.json` `permissions.ask` para acciones hacia afuera:
   Slack send/schedule, Gmail send/forward/reply, Calendar create/update/delete, Jira create/edit/
   transition/comment, GitHub merge/create PR/push_files, Drive share/trash. Sin hooks nuevos.
7. **Docs**: README (sección Integraciones + índice ADR), `.agents/CONTEXT.md`, copiar este plan a
   `docs/superpowers/plans/2026-11-08-integrations.md`.
8. **Obsidian (documentación generada)**: `scripts/export-obsidian.sh` escribe en el vault
   `agents-config/`: `agents-config.md` (estructura, install, routing), `skills/<name>.md` (una por
   skill, desde los SKILL.md, incluyendo plugins), `integraciones.md` (MCPs, plugins, parche, cómo
   desinstalar), `pendientes.md` (graphify, impeccable, higgsfield, n8n). Re-ejecutable.
9. **MiBiblio**: tras login, leer el notebook vía MCP y escribir `projects/mibiblio/{mibiblio,plan,fuentes}.md`
   (+ export de fuentes); link desde README del repo MiBiblio.
10. Commit en rama `feat/integrations` de agents-config (repo personal), push/PR con confirmación.
    Trabajo mecánico de skills/notas (pasos 5 y 8) → `worker` con spec y comando de aceptación.

## Verificación
- `bash -n install.sh`, `scripts/gen-plugin.sh --check`, `jq . config/*.json`, hooks pre-commit.
- `./install.sh --profile loren` en seco/backup: `claude plugin list` y `claude mcp list` muestran todo;
  vercel no cambia sin decidirlo; parche paste-preview presente (`grep "local patch"`).
- Tras `/reload-plugins`: `/codex:status`; MCP NotebookLM lista notebooks; MCP Obsidian busca en el vault;
  enviar un Slack de prueba pide confirmación.
- Notas en el vault abren en Obsidian; links internos resuelven.

## Rollback
- Backups `settings.json.bak.<ts>` de install.sh; `claude plugin uninstall`, `claude mcp remove`,
  `uv tool uninstall notebooklm-py`; revertir el PR.
