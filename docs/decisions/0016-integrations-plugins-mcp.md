# 0016 — Integraciones: plugins, MCP de usuario y barandas para lo que sale

Estado: aceptado (2026-11-08).

## Contexto

El hub no versionaba los plugins de terceros ni los servidores MCP en uso, volver a correr `install.sh`
apagaba plugins prendidos a mano, y nada limitaba lo que un agente manda por Slack, Gmail, Calendar, Jira,
GitHub o Drive. Había MCP por proyecto (ADR 0011) pero no una capa personal global.

## Decisión

- **Conectores de cuenta** (Slack, Atlassian/Jira, GitHub, Gmail, Calendar, Drive): vienen de la cuenta de
  claude.ai y no se declaran en archivos. El hub suma solo skills de uso y barandas.
- **Plugins** declarados en `config/settings.base.json` (`enabledPlugins` + `extraKnownMarketplaces`,
  fusionados clave por clave por `install.sh`): paste-preview, mattpocock-skills, claudex-loop, codex,
  claude-obsidian, andrej-karpathy-skills, skill-creator y modern-web-guidance (del equipo de Chrome; global
  para que llegue a todo front, repos de org incluidos; corre `npx modern-web-guidance@latest`, que necesita
  red).
  - El plugin `github` queda apagado: falla al autenticar y duplica el conector de claude.ai y `gh`.
  - El plugin de Vercel queda prendido: se había prendido a mano, y la base lo apagaba y `install.sh` lo iba a
    desactivar en la próxima corrida.
  - n8n, impeccable, higgsfield y graphify quedan afuera por ahora.
- **MCP de usuario** en `config/mcp.user.json`, registrados por `install.sh --with-integrations`
  (`claude mcp add-json --scope user`, idempotente, sin secretos): `notebooklm` (`notebooklm-py` fijado, login
  a mano) y `obsidian` (`@bitbonsai/mcpvault` fijado; lee y escribe el vault por filesystem, confinado a él;
  ruta desde `$OBSIDIAN_VAULT`). Es una excepción deliberada a «MCP opt-in por repo»: son herramientas
  personales, no de un stack. Los servidores propios de la máquina (por ejemplo `cao-mcp-server`) quedan
  afuera.
- **Barandas**: `permissions.ask` en `settings.base.json` cubre las herramientas que mandan algo afuera o son
  difíciles de revertir (enviar, agendar, crear/editar/borrar eventos, crear/editar/transicionar en Jira,
  mergear/crear PR, push de archivos, compartir o mandar a la papelera en Drive, borrar/mover en Obsidian).
  Lecturas y borradores no se frenan.
- **Parche local**: paste-preview abre su editor en cada pegado y no tiene setting para evitarlo.
  `config/patches/paste-preview-no-autoedit.sh` comenta esa línea; `install.sh` lo vuelve a correr
  (idempotente) porque una actualización del plugin lo pisa. El botón Edit sigue abriendo el editor.
- Los plugins se auditaron desde el código antes de declararlos (hooks, red, exec). El Stop review gate de
  Codex queda apagado (opt-in en el plugin); el contexto de SessionStart de claude-obsidian viene apagado por
  defecto.

## Consecuencias

- `install.sh` toca más de la máquina solo con `--with-integrations`; las corridas normales solo fusionan
  settings y reaplican el parche.
- Las versiones fijadas necesitan una subida deliberada.
- El parche de paste-preview se puede romper si upstream cambia esa línea (el script avisa en vez de fallar).
- Las escrituras por el MCP de Obsidian no se frenan salvo borrar y mover: el vault va con backup o git.
