# Organizaciones

Cada organización (empleador, cliente) es **su propio repo git privado**, clonado en
`organizations/<name>/`. Este repo público nunca lo versiona (`.gitignore`), nunca guarda su URL, y
`scripts/leak-guard.sh` falla si se versiona uno. Se administran con `scripts/orgs.sh`.

Una organización suma sus políticas, skills, comandos y preguntas de entrevista sobre la base. Las reglas de
trabajo que hereda todo repo de una org (rama por tarea desde la base remota, nunca commitear en
`main`/`dev`, preguntar antes de push o PR, aprobar el texto del tracker, sugerir issues) están resumidas en
`config/AGENTS.md`, sección «Organizations», y completas en la skill `github-usage`. Puede cambiar convenciones (rama base, formato de PR, idioma,
tracker, design system), nunca `config/baseline.md`; cuando reemplaza una práctica base, el proyecto lo
registra en un ADR.

## Contrato

```
organizations/<name>/
  org.json          obligatorio
  POLICIES.md       obligatorio: primero un resumen de 15 líneas o menos, después una sección por tema
  skills/<name>/SKILL.md
  commands/<name>.md
  interview.md      preguntas extra para project-init (opcional)
  scripts/          scripts que usan las skills y comandos de la org (opcional, no se copian a los proyectos)
  workspaces/<slug>/  config de workspaces multi-repo, la escribe workspace.sh de project-init (opcional)
```

Un repo de org también puede ser **autosuficiente**, para que alguien del equipo lo use sin este hub. En ese
caso suma:

```
  .claude-plugin/   plugin.json + marketplace.json: se instala como plugin de Claude Code
  hooks/            hooks.json + scripts: un hook SessionStart que muestra el resumen de POLICIES.md
  install.sh        instala skills, comandos y POLICIES.md en ~/.claude, o en un proyecto con
                    --project <path>; guarda un manifiesto, soporta --dry-run y --uninstall; se niega
                    a instalar en un proyecto que ya usa agents-config
  AGENTS.md         mapa del repo de la org para cualquier agente
  README.md         las dos formas de instalarlo
```

El hub lee solo `org.json`, `POLICIES.md`, `skills/`, `commands/` (o, con `products`, los de cada carpeta
`<product>/`), `interview.md` y `workspaces/`; `orgs.sh` y `project-agents.sh` ignoran los archivos de la
versión autosuficiente. `project-agents.sh` rechaza un directorio de org que tenga symlinks: las dependencias
van fuera del repo (por ejemplo, en `~/.cache`).

`org.json`:

```json
{
  "name": "acme",
  "version": "0.1.0",
  "extends": "agents-config>=0.1.0",
  "match": { "gh_owners": ["acme-inc"], "remote_patterns": [] },
  "defaults": {
    "base_branch": "dev",
    "commit_language": "en",
    "pr_title_language": "en",
    "pr_body_language": "en",
    "tracker": "none",
    "tracker_project": ""
  },
  "blocklist_terms": ["acme"],
  "replaces": {
    "ui-builder": "acme-ui-builder",
    "github-usage": "acme-github",
    "/smart-commit": "/acme-commit"
  },
  "assets": { "commands/acme-commit.md": { "stacks": ["react-vite"] } },
  "index": [{ "when": "Create a ticket", "use": "acme-ticket" }],
  "critical": [{ "skill": "acme-erp", "keywords": "erp|invoice sync" }]
}
```

| Clave | Obligatoria | La lee | Significado |
|---|---|---|---|
| `name` | sí | `orgs.sh`, `project-agents.sh` | Igual al nombre del directorio; minúsculas, dígitos y `-` |
| `version` | sí | `orgs.sh status`, `.agents/skills.lock` | Versión propia de la org; los proyectos la congelan |
| `extends` | no | `orgs.sh status` | Versión mínima de la base, `agents-config>=x.y.z`; `status` avisa si la base es más vieja |
| `match` | sí | `orgs.sh detect`, `init.sh`, el índice global | `gh_owners` (owners de GitHub) y `remote_patterns` (regex sobre la URL del remoto); al menos una entrada en total |
| `defaults` | no | los agentes (e `intent-router.sh` para `base_branch`) | Convenciones de la org en un solo lugar: `base_branch`, `commit_language`, `pr_title_language`, `pr_body_language`, `tracker`, `tracker_project` y cualquier clave descriptiva extra (resumen del stack, proyectos del tracker por repo, ...). Solo un script lee `base_branch`; para el resto, la fuente legible es `POLICIES.md` |
| `blocklist_terms` | no | `orgs.sh` | Palabras que nunca pueden aparecer en el repo público; se suman al blocklist local de leak-guard junto con `name` y `match.gh_owners` |
| `replaces` | no | `orgs.sh validate`, `project-agents.sh` | Mapa plano `nombre base -> nombre de la org`. Una skill es un nombre a secas, un comando empieza con `/`; una skill solo se reemplaza por una skill y un comando por un comando. El destino tiene que existir en `skills/` o `commands/` de la org. Lo reemplazado puede ser una skill de pack, de stack o una skill de integración del hub (`github-usage`, `jira-usage`, ...) |
| `assets` | no | `project-agents.sh` | Filtro por stack para cada archivo, con clave `skills/<name>` o `commands/<name>.md`; un archivo sin entrada se instala en todos los stacks |
| `products` | no | `orgs.sh validate`, `project-agents.sh` | Para una org con varias líneas de producto: `{"<product>": {"remote_patterns": [regex, ...]}}`. Cada producto tiene sus `skills/`, `commands/` y un `POLICIES.md` completo en `<product>/`; el `POLICIES.md` de la raíz se queda (el núcleo común al que apunta el índice global). `project-agents.sh` toma `--product <name>` o elige el que coincide con el `origin` del proyecto (en una carpeta workspace, con sus repos hijos); si no coincide exactamente uno, falla cerrado. Los destinos de `replaces`, las claves de `assets` y las filas de `index`/`critical` se refieren al producto instalado |
| `shared` | no | `orgs.sh validate`, `project-agents.sh` | Nombre de una carpeta de la org con `skills/` y `commands/` comunes a todos los productos, que llegan por fuera del hub (por ejemplo, un plugin de Claude Code instalado a nivel usuario). `orgs.sh validate` la revisa como a un producto y acepta ahí los destinos de `replaces`; `project-agents.sh` no la copia, pero igual saca lo que esos `replaces` reemplazan (ADR 0062) |
| `index` / `critical` | no | `project-agents.sh` | Filas para la tabla de palabras clave del proyecto y para `.agents/critical.json`, mergeadas antes que las de los packs. Una fila puede llevar `"stacks": [...]` |

**`intents.json`** (opcional, en la raíz de la org, no en `org.json`): recordatorios del `intent-router`.
Cuando un agente corre a mano en un repo de la org un comando que un script de la org ya resuelve, el
hook le sugiere el script, una vez por sesión y por `id`: `{"bash": [{"id": "...", "re": "<regex por
comando>", "hint": "<qué usar>"}]}`. Cada `re` se prueba contra cada comando de la línea (partida por
`&&`, `;` y `||`). Callado dentro de subagentes, como el resto del router (ADR 0051).

Notas:

- `pr_title_language` y `pr_body_language` van separados a propósito: una org puede pedir títulos
  Conventional Commits en inglés y el cuerpo en español, o al revés. Reemplazan al viejo `pr_language`.
- `blocklist_terms` no puede conservar el `acme` de la plantilla (la validación falla).
- Cuando un reemplazo aplica a un proyecto, `project-agents.sh` saca la skill o el comando reemplazado del
  `.claude/` del proyecto, reescribe las referencias en las skills y comandos que instaló, y apunta las filas
  de `index` y `critical` al reemplazo.

## Uso

```
scripts/orgs.sh add <name> <git-url>     clona, valida y registra
scripts/orgs.sh add <name> --init        crea una org local nueva desde _template/
scripts/orgs.sh validate <name|path>     revisa el contrato
scripts/orgs.sh detect <owner|remote>    qué org es dueña de este repo
scripts/orgs.sh list | status | index    lista, estado (versión y extends), regenera organizations/INDEX.md
scripts/orgs.sh pull                     fast-forward de cada org y la valida
scripts/orgs.sh push <name> [--yes]      pushea un repo de org, pregunta antes
scripts/orgs.sh remove <name> [--force]  se niega con cambios sin commitear o sin pushear salvo --force
```

`install.sh --org <name> <git-url>` hace el mismo `add` e importa el índice `organizations/INDEX.md` en los
archivos generados.

project-init pregunta a qué org pertenece un proyecto (propone la detectada) y después
`project-agents.sh --org <name>` copia las skills y comandos de la org, mergea sus filas de índice y críticas,
y copia `POLICIES.md` a `.agents/POLICIES.md`. El proyecto congela las versiones de la base y de la org en
`.agents/skills.lock`; las actualizaciones son siempre explícitas.

`orgs.sh validate` corre solo en `add`, en `pull` y antes de que `project-agents.sh --org` instale algo
(falla cerrado). Es una ayuda: atrapa errores y frases obvias que debilitan el baseline, no vuelve segura a
una org en la que no se confía. `init.sh` pregunta antes de copiar el `POLICIES.md` de una org a un proyecto
cuyo owner no está en sus `gh_owners` (`--allow-org-mismatch` para seguir).

Para crear la org de un cliente nuevo, usar la skill `org-creator`.
