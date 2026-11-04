# Baseline (no negociable)

Vale en todo proyecto y toda organización. Una org puede pisar convenciones (rama base, formato de PR, idioma, tracker, design system), nunca esto.

1. **Secretos**: nunca en repo, logs ni prompts. `.env` ignorado; asumir que el repo puede ser público.
2. **Verificar antes de "listo"**: correr el check más chico que cubra el cambio (test, lint, typecheck, build) y reportar qué corrió y qué no.
3. **Mínimo privilegio**: IAM, DB y tokens con el alcance mínimo; datos de prod en solo lectura por defecto.
4. **Git seguro**: sin force-push a ramas compartidas, sin comandos destructivos sin pedido explícito, no pisar cambios ajenos.
5. **Decisiones críticas** (arquitectura, datos, auth, deploy): se preguntan, no se asumen, y quedan en un ADR.
6. **Acciones hacia afuera** (push, publicar, deployar, crear repos remotos): confirmación previa.
7. **Política de org que reemplaza una práctica base**: se registra en un ADR del proyecto.
