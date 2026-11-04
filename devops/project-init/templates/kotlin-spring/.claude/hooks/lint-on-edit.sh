#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit) hook: format the edited source file in place with
# the project's Spotless. Formatting only and never blocks: the full check
# (format + compile + tests) is CI's job and `scripts/gh-flow.sh pr`.
set -uo pipefail

payload="$(cat)"
f="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' <<<"$payload" 2>/dev/null)"
[ -n "$f" ] && [ -f "$f" ] || exit 0
case "${f##*.}" in java|kt|kts) ;; *) exit 0 ;; esac

root="$(dirname "$f")"
while [ "$root" != "/" ] && [ ! -x "$root/mvnw" ] && [ ! -x "$root/gradlew" ]; do root="$(dirname "$root")"; done
cd "$root" 2>/dev/null || exit 0

re="$(printf '%s' "$f" | sed 's/[][\.*^$+?(){}|]/\\&/g')"
if [ -x ./mvnw ]; then
  ./mvnw -q -B spotless:apply "-DspotlessFiles=$re" >/dev/null 2>&1 || true
elif [ -x ./gradlew ]; then
  # -PspotlessIdeHook formats only this file; -PspotlessFiles is ignored by Gradle and would
  # reformat the whole project on every edit (verified in e2e.sh).
  ./gradlew -q spotlessApply "-PspotlessIdeHook=$f" >/dev/null 2>&1 || true
fi
exit 0
