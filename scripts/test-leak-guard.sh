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

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
