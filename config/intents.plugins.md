# Plugin shortcuts

Shortcuts for plugin skills, whose own files are overwritten on update: one heading per skill, with the
`## Shortcuts` bullets described in `scripts/gen-intents.sh`. Run that script after editing this file.

## mattpocock-skills:diagnosing-bugs
- intent: unknown-cause bug — `no s[eé] por qu[eé] (falla|pasa|anda|rompe)|why (is|does) .* (fail|break|crash)|root cause|causa ra[ií]z|intermitente|flaky` → `reproduce, isolate, form a hypothesis and verify it before changing code; use debug-assistant only for a pasted stack trace`

## mattpocock-skills:tdd
- intent: test first — `\btdd\b|test[- ]first|escrib[ií] (el )?test primero|red[- ]green` → `write the failing test, make it pass, refactor; write tests with unit-test-generator, run only the tests you wrote`

## mattpocock-skills:grilling
- intent: stress-test an idea — `gr[ií]ll?ame|grill me|estres[aá] (esta|mi) idea|stress[- ]test (this|my) (idea|plan)` → `interview the user relentlessly about the idea before building anything`
- intent: design before building — `brainstorm|pensemos (el )?dise[ñn]o|dise[ñn]emos|armemos un plan|let'?s design|plan this feature` → `grill the user until nothing is left to assume, then read the plugin's to-spec SKILL.md and follow it: the spec goes to .scratch/<topic>/spec.md (local, never committed)`
