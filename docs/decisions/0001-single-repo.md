# 0001 — Un solo repo para la config de agentes y las skills

Estado: aceptado (2026-10-10).

## Contexto

Las skills de AWS vivían en otro repo (`LorenGrz/aws-skills`), enlazado con symlinks e ignorado, y
`LorenGrz/serverless-scanner-skill` repetía una de ellas: tres repos sin versionado ni releases propios para
el setup de una sola persona.

## Decisión

- `aws-skills` se incorpora en `aws/` con `git subtree add --prefix=aws`, conservando su historial. Se quitan
  los symlinks externos y sus entradas en `.gitignore`.
- El `SKILL.md` y los cuatro `references/*.md` de `serverless-scanner-skill` eran idénticos byte a byte a
  `aws/serverless-scanner`: queda solo esa copia (la del subtree), sin `aws/serverless-scanner-migration`.
- El repo (entonces `LorenGrz/claude-skills`) se renombra en GitHub a `LorenGrz/agent-config`: es el hub de
  config y skills de todas las IA, no solo skills.
- Oracle APEX (`apexlang`) y Omarchy (`omarchy`, `diagnose-crash`) siguen como symlinks externos: pertenecen a
  otros proyectos o al sistema y se actualizan aparte.

## Consecuencias

- Un `git clone` + `install.sh` instala skills, rules, hooks, subagentes y settings.
- El glob de `sync.sh` (`<category>/<skill>/SKILL.md`, dos niveles) ya cubre `aws/<skill>/SKILL.md`.
