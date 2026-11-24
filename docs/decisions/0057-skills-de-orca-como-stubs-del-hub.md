# 0057 — Las skills de Orca son stubs del hub, adaptados a los carriles

Estado: aceptado (2026-11-24). Ajusta 0056 (paso de skills de `orca-setup.sh`).

## Contexto

Orca 1.4.273 trae 11 skills. Las que usa el hub (`orca-cli`, `orca-computer-use`, `orchestration`) son stubs:
cargan la guía de la versión instalada con `orca skills get`, así que su contenido nunca queda viejo. Lo único
que cambia entre versiones es el frontmatter, que decide cuándo se activan.

`orca skills install|update` no sirve para mantenerlos: escribe en `~/.agents/skills`, que es `skills/` de este
repo (dejaría carpetas sueltas fuera de `skills/<categoría>/`), y saltea `~/.claude/skills` porque ahí ya hay
una skill con ese nombre. Un install viejo dejó symlinks rotos en `~/.cursor`, `~/.grok`, `~/.kiro` y
`~/.gemini/config/skills`. Sin `--skill` ni `--all`, los dos comandos solo listan y salen con 0, así que el paso
2 de `orca-setup.sh` no hacía nada.

La descripción nueva de `orchestration` activa workers de Orca cuando se pide repartir o paralelizar cambios de
código, lo que choca con los carriles de `config/AGENTS.md` (workers como subagentes, líderes con Orquestar).

## Decisión

- Los stubs viven en `skills/meta/<nombre>/SKILL.md` y `sync.sh` los enlaza; Orca no los instala.
- `orca-cli` y `orca-computer-use` copian el stub de Orca tal cual. `orchestration` toma lo nuevo
  (`/orchestration`, un agente con nombre, Codex) pero deja el paralelismo de código a los carriles.
- Las otras 8 skills de Orca (Jira, Linear, emuladores, plugins, entornos por workspace) no se suman hasta que
  haga falta; en un repo de una org sigue mandando la skill de Jira de esa org.
- `orca-setup.sh` ya no llama al instalador de Orca: solo recuerda dónde están.
- Al actualizar Orca: `HOME=<carpeta temporal> orca-ide skills install --all --agent universal`, `diff` de cada
  `SKILL.md` contra `skills/meta/`, y adoptar los cambios del frontmatter (el cuerpo es el mismo cargador).

## Consecuencias

- Los bots (Orca 1.4.273) no necesitan skill propia: su guía es `orca skills get orca-cli --reference bots`.
- Una descripción adaptada puede quedar atrás de Orca sin aviso; el diff de arriba es la forma de verlo.
