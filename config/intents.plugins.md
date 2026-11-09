# Plugin shortcuts

Shortcuts for skills that come from plugins. Plugin files are overwritten on update, so their
`## Shortcuts` sections can't live in the skill itself: each skill gets its own heading here, with the
same bullets described in `scripts/gen-intents.sh`. Run that script after editing this file.

## superpowers:systematic-debugging
- intent: unknown-cause bug — `no s[eé] por qu[eé] (falla|pasa|anda|rompe)|why (is|does) .* (fail|break|crash)|root cause|causa ra[ií]z|intermitente|flaky` → `reproduce, isolate, form a hypothesis and verify it before changing code; use debug-assistant only for a pasted stack trace`

## superpowers:test-driven-development
- intent: test first — `\btdd\b|test[- ]first|escrib[ií] (el )?test primero|red[- ]green` → `write the failing test, make it pass, refactor; write tests with unit-test-generator, run them with execute-test-suite`

## superpowers:brainstorming
- intent: design before building — `brainstorm|pensemos (el )?dise[ñn]o|dise[ñn]emos|armemos un plan|let'?s design|plan this feature` → `brainstorm, write the spec in docs/superpowers/specs/, then writing-plans for the plan in docs/superpowers/plans/`

## mattpocock-skills:grilling
- intent: stress-test an idea — `gr[ií]ll?ame|grill me|estres[aá] (esta|mi) idea|stress[- ]test (this|my) (idea|plan)` → `interview the user relentlessly about the idea before building anything`
