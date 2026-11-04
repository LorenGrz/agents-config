#!/usr/bin/env bash
# test-leak-guard.sh - offline checks for scripts/leak-guard.sh and the git hooks, in a temporary repo.
# The blocklist term is synthetic; the guard must never echo it.
set -uo pipefail
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
T="zorgblat"                                   # synthetic blocklist term
pass=0; failn=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else failn=$((failn + 1)); echo "FAIL $1"; fi; }

R="$W/repo"; mkdir -p "$R/scripts" "$R/.githooks" "$R/organizations/_template"
cp "$REAL/scripts/leak-guard.sh" "$R/scripts/"; cp "$REAL/.githooks/commit-msg" "$REAL/.githooks/pre-push" "$R/.githooks/"
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/scripts/leak-guard.sh" --staged\n' > "$R/.githooks/pre-commit"
chmod +x "$R"/scripts/* "$R"/.githooks/*
git -C "$R" init -q -b main; git -C "$R" config user.name t; git -C "$R" config user.email t@t.invalid
git -C "$R" config core.hooksPath .githooks
printf '%s\n' "$T" > "$W/blocklist"
export LEAK_BLOCKLIST_FILE="$W/blocklist"
unset LEAK_BLOCKLIST CI
G="$R/scripts/leak-guard.sh"
guard() { (cd "$R" && "$G" "$@") 2>&1; }
commit() { (cd "$R" && GIT_COMMITTER_NAME=t git -c core.hooksPath=/dev/null commit -q --allow-empty -m "$1" 2>&1); }

echo base > "$R/ok.txt"; git -C "$R" add ok.txt; commit "init"
check "clean tree passes --all" 'guard --all >/dev/null'

# content
echo "this mentions $T here" > "$R/c.txt"; git -C "$R" add c.txt
out="$(guard --staged)"; rc=$?
check "term in staged content fails" '[ $rc -ne 0 ]'
check "output never contains the term" '! grep -qi "$T" <<<"$out"'
git -C "$R" reset -q; rm "$R/c.txt"

# file name (also empty file)
: > "$R/notes-$T.md"; git -C "$R" add "notes-$T.md"
out="$(guard --staged)"; rc=$?
check "term in an (empty) file name fails" '[ $rc -ne 0 ]'
check "output redacts a path that contains the term" '! grep -qi "$T" <<<"$out"'
git -C "$R" reset -q; rm "$R/notes-$T.md"

# binary content
printf '\x00\x01binary %s \x02' "$T" > "$R/b.bin"; git -C "$R" add b.bin
guard --staged >/dev/null; rc=$?
check "term inside a binary file fails" '[ $rc -ne 0 ]'
git -C "$R" reset -q; rm "$R/b.bin"

# rename into a term path
git -C "$R" mv ok.txt "moved-$T.txt"
guard --staged >/dev/null; rc=$?
check "a pure rename to a path with the term fails" '[ $rc -ne 0 ]'
git -C "$R" reset -q --hard

# commit message through the real hook
echo x > "$R/m.txt"; git -C "$R" add m.txt
git -C "$R" commit -q -m "feat: add $T support" >/dev/null 2>&1; rc=$?
check "commit-msg hook rejects a message with the term" '[ $rc -ne 0 ]'
git -C "$R" commit -q -m "feat: harmless" >/dev/null 2>&1
check "commit-msg hook accepts a clean message" '[ "$(git -C "$R" log --oneline | wc -l)" -eq 2 ]'

# history range and --all with a message already in history
commit "bad $T message"
guard --log "HEAD~1..HEAD" >/dev/null; rc=$?
check "--log finds a term in a commit message" '[ $rc -ne 0 ]'
out="$(guard --log "HEAD~1..HEAD")"
check "--log output never contains the term" '! grep -qi "$T" <<<"$out"'

# organizations tracked
mkdir -p "$R/organizations/zzorg"; echo x > "$R/organizations/zzorg/a.md"; git -C "$R" add -f organizations/zzorg/a.md
out="$(guard --staged)"; rc=$?
check "tracked organizations/<org> files fail, without printing paths" '[ $rc -ne 0 ] && ! grep -q "zzorg" <<<"$out"'
git -C "$R" reset -q; rm -rf "$R/organizations/zzorg"

# secrets
# the fake key is built at runtime so no literal key exists in this repo
echo "k=AKIA$(printf %s ABCDEFGHIJKLMNOP)" > "$R/s.txt"; git -C "$R" add s.txt
guard --staged >/dev/null; rc=$?
check "an AWS key is caught" '[ $rc -ne 0 ]'
git -C "$R" reset -q; rm "$R/s.txt"

# no blocklist
check "no blocklist locally: warns but passes" '(unset LEAK_BLOCKLIST_FILE; export HOME="$W/nohome"; cd "$R" && ./scripts/leak-guard.sh --all >/dev/null 2>&1)'
check "no blocklist in CI: fails" '! (unset LEAK_BLOCKLIST_FILE; export HOME="$W/nohome" CI=true; cd "$R" && ./scripts/leak-guard.sh --all >/dev/null 2>&1)'
check "blocklist from the LEAK_BLOCKLIST env works in CI" '(unset LEAK_BLOCKLIST_FILE; export HOME="$W/nohome" CI=true LEAK_BLOCKLIST="other-term"; cd "$R" && ./scripts/leak-guard.sh --all >/dev/null 2>&1)'

# --- re-review regressions
zero=0000000000000000000000000000000000000000
printf 'x %s y\n' "$T" > "$R/a|b.txt"; git -C "$R" add "a|b.txt"
guard --staged >/dev/null; rc=$?
check "a file name with | does not make the staged scan fail open" '[ $rc -ne 0 ]'
git -C "$R" reset -q; rm -f "$R/a|b.txt"

printf 'x %s y\n' "$T" > "$R/a:$T.txt"; git -C "$R" add "a:$T.txt"
out="$(guard --staged)"
check "a path with ':' that holds the term is fully redacted" '! grep -qi "$T" <<<"$out"'
git -C "$R" reset -q; rm -f "$R/a:$T.txt"

# a term added and removed in later commits is still in the pushed history (patch scan)
echo "added $T" > "$R/tmp.txt"; git -C "$R" add tmp.txt; commit "add notes"
git -C "$R" rm -q tmp.txt; commit "drop notes"
guard --log "HEAD~2..HEAD" >/dev/null; rc=$?
check "--log scans patches (term added then removed)" '[ $rc -ne 0 ]'
out="$(guard --log "HEAD~2..HEAD")"; check "--log patch hits do not print the term" '! grep -qi "$T" <<<"$out"'

guard --refs "feat-$T" >/dev/null; rc=$?
check "--refs rejects a branch name with the term" '[ $rc -ne 0 ]'
guard --refs "feat-clean" >/dev/null; check "--refs accepts a clean name" '[ $? -eq 0 ]'
sha="$(git -C "$R" rev-parse HEAD)"
printf 'refs/heads/x %s refs/heads/feat-%s %s\n' "$sha" "$T" "$zero" | (cd "$R" && .githooks/pre-push origin url >/dev/null 2>&1); rc=$?
check "pre-push blocks a remote branch name with the term" '[ $rc -ne 0 ]'
git -C "$R" tag -a vtag -m "release $T notes" >/dev/null 2>&1
tsha="$(git -C "$R" rev-parse vtag)"
printf 'refs/tags/vtag %s refs/tags/vtag %s\n' "$tsha" "$zero" | (cd "$R" && .githooks/pre-push origin url >/dev/null 2>&1); rc=$?
check "pre-push blocks an annotated tag whose message has the term" '[ $rc -ne 0 ]'
printf 'refs/heads/main %s refs/heads/main %s\n' "$sha" "$(git -C "$R" rev-parse HEAD~3)" | (cd "$R" && .githooks/pre-push origin url >/dev/null 2>&1); rc=$?
check "pre-push blocks a range whose history has the term" '[ $rc -ne 0 ]'

guard --log "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef..HEAD" >/dev/null; rc=$?
check "--log with an unknown range fails instead of passing" '[ $rc -eq 2 ]'

printf '  other-term  \r\n%s \r\n' "$T" > "$W/crlf-blocklist"
echo "x $T" > "$R/crlf.txt"; git -C "$R" add crlf.txt
(export LEAK_BLOCKLIST_FILE="$W/crlf-blocklist"; cd "$R" && ./scripts/leak-guard.sh --staged >/dev/null 2>&1); rc=$?
check "blocklist lines with CRLF and spaces still match" '[ $rc -ne 0 ]'
git -C "$R" reset -q; rm -f "$R/crlf.txt"

printf 'feat: fine\n\n# Changes to be committed:\n# diff mentions %s\n' "$T" > "$W/msg-v.txt"
guard --message "$W/msg-v.txt" >/dev/null; rc=$?
check "git comment lines (commit -v) are not scanned as the message" '[ $rc -eq 0 ]'

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
