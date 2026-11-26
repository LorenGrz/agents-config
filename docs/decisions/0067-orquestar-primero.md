# 0067 — Orquestar va primero y se recomienda por criterio, no por tamaño

Estado: aceptado (2026-11-26). Ajusta 0040 (orden y recomendación de la pregunta Continuar · Orquestar).

## Contexto

Con 0040 la segunda pregunta iba siempre Continuar · Orquestar, y con una sola rama se recomendaba por
tamaño. Un ticket chico de front o back quedaba en la sesión principal, que desde la carpeta del workspace
no carga las skills de cada repo ni sus skills de review. Loren pidió que Orquestar sea la primera opción y
que la recomendación dependa del criterio que pide el cambio, no de su tamaño.

## Decisión

- La pregunta va en este orden fijo: **Orquestar** · **Continuar**. `lane-guard.sh` lo impone y niega el
  orden inverso. La pregunta de carril (Continuar · Plan S · Plan L) no cambia.
- Se recomienda Orquestar cuando es un ticket que toca un repo con skills propias (front, back): el líder
  trabaja en ese repo con sus skills y se autorrevisa con las de review. También con más de una rama.
- Se recomienda Continuar para un arreglo que pide poco criterio.
- La recomendada se marca con «(Recomendado)» sin moverla de lugar, como en la pregunta de carril.

## Consecuencias

- Más tickets van a un líder en su worktree; cuesta una sesión más, a cambio de usar las skills del repo.
- Los líderes siguen sin lanzar reviewers (0048): la revisión Standards y Spec la lanza la sesión padre.
- Las copias de la regla en el repo de una org (por ejemplo, el `AGENTS.md` de un workspace) pueden
  seguir escribiendo «Continuar · Orquestar». Mandan la regla del hub y el hook; esas copias se alinean en
  el repo de la org.
