---
description: Summarize the session as a numbered list grouped by topic, marking what was tried and reverted. $ARGUMENTS - optional topic to summarize.
argument-hint: (empty = whole session) or the topic/feature
---

Summarize this session so someone, or a fresh session, can resume without rereading it. Scope: $ARGUMENTS (empty = whole session). Use the user's language.

1. **No tools.** Everything comes from the conversation: no reading files, no `git`, no verification.
2. **Numbered list grouped by topic** (`## Topic` + items). One item = one fact, no paragraphs.
3. **Final state first.** Each item says how things ended up, not the path. Something done and then reverted or replaced goes as a sub-item of the final one prefixed `undone:` with a half-line reason; never as a top-level item, or a reader may re-apply it.
4. Name the files for code changes.
5. End with `## Pending`: what is not done, what failed and was not fixed, decisions the user left open. Write "nothing" if empty.
6. Leave out other sessions' changes, tool noise, dead-end searches, rewordings, verification of what was implemented and files that needed no change.
7. No preamble or closing. Start at the first `##`; aim for 40 items or fewer.
