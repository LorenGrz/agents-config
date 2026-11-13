#!/usr/bin/env bash
# test-docs-check.sh - offline checks for templates/common/scripts/docs-check.sh: which edits count
# as a dependency change (warn) and which do not (project version, tasks, formatting, tool config).
set -uo pipefail
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DC="$SD/../templates/common/scripts/docs-check.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; failn=0

# t <name> <file> <expect: warn|quiet> <base-content> <new-content> [extra-file-changed-in-the-branch]
t() {
  local name="$1" file="$2" expect="$3" base="$4" new="$5" extra="${6:-}" r out
  r="$(mktemp -d -p "$W")"
  git -C "$r" init -q -b main; git -C "$r" config user.name t; git -C "$r" config user.email t@t.invalid
  mkdir -p "$r/$(dirname "$file")"; printf '%s\n' "$base" > "$r/$file"; echo "# docs" > "$r/AGENTS.md"
  git -C "$r" add -A; git -C "$r" commit -q -m base
  git -C "$r" update-ref refs/remotes/origin/dev HEAD
  git -C "$r" checkout -q -b feat
  printf '%s\n' "$new" > "$r/$file"; [ -n "$extra" ] && echo "more" >> "$r/$extra"
  git -C "$r" add -A; git -C "$r" commit -q -m change
  out="$(cd "$r" && BASE_REF=dev bash "$DC" 2>&1)"
  if [ "$expect" = warn ]; then grep -q "dependency change in $file" <<<"$out" && ok=1 || ok=0
  else ! grep -q "dependency change" <<<"$out" && ok=1 || ok=0; fi
  if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "ok   $name"; else failn=$((failn + 1)); echo "FAIL $name"; echo "$out" | sed 's/^/     /'; fi
}

PKG='{"name":"a","scripts":{"dev":"vite"},"dependencies":{"react":"19"}}'
t "package.json: dependency added" package.json warn "$PKG" '{"name":"a","scripts":{"dev":"vite"},"dependencies":{"react":"19","zod":"4"}}'
t "package.json: scripts only" package.json quiet "$PKG" '{"name":"a","scripts":{"dev":"vite","lint":"eslint ."},"dependencies":{"react":"19"}}'

POM='<project><version>0.0.1</version><dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
  </dependency>
</dependencies><build><plugins><plugin><artifactId>p</artifactId><version>1</version></plugin></plugins></build></project>'
t "pom: dependency added" pom.xml warn "$POM" "${POM/<\/dependencies>/<dependency><groupId>x</groupId><artifactId>y</artifactId></dependency></dependencies>}"
t "pom: dependency version changed" pom.xml warn "$POM" "${POM/spring-boot-starter-web<\/artifactId>/spring-boot-starter-web</artifactId><version>9</version>}"
t "pom: project version and plugin only" pom.xml quiet "$POM" "${POM/0.0.1/0.0.2}"
t "pom: plugin version only" pom.xml quiet "$POM" "${POM/<version>1<\/version>/<version>2</version>}"

GR="plugins {
  id 'java'
  id 'org.springframework.boot' version '4.1.2'
}
dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-web'
}
tasks.named('test') { useJUnitPlatform() }"
t "gradle: dependency added" build.gradle warn "$GR" "${GR/  implementation \'org.springframework.boot:spring-boot-starter-web\'/  implementation \'org.springframework.boot:spring-boot-starter-web\'
  implementation \'a:b:1\'}"
t "gradle: plugin version bumped" build.gradle warn "$GR" "${GR/4.1.2/4.1.3}"
t "gradle: task edit only" build.gradle quiet "$GR" "${GR/useJUnitPlatform()/useJUnitPlatform(); maxHeapSize = \'1g\'}"
t "gradle kts: dependency added" app/build.gradle.kts warn 'dependencies { implementation("a:b:1") }' 'dependencies { implementation("a:b:1")
  testImplementation("c:d:2") }'
t "version catalog: version changed" gradle/libs.versions.toml warn '[versions]
spring = "4.1.2"' '[versions]
spring = "4.1.3"'
t "version catalog: comment only" gradle/libs.versions.toml quiet '[versions]
spring = "4.1.2"' '# bump later
[versions]
spring = "4.1.2"'

PY='[project]
name = "a"
version = "0.1.0"
dependencies = [
  "pydantic>=2",
]
[tool.ruff]
line-length = 100'
t "pyproject: dependency added" pyproject.toml warn "$PY" "${PY/\"pydantic>=2\",/\"pydantic>=2\",
  \"httpx\",}"
t "pyproject: project version bump" pyproject.toml quiet "$PY" "${PY/0.1.0/0.2.0}"
t "pyproject: ruff config change" pyproject.toml quiet "$PY" "${PY/100/88}"
t "pyproject: dependency group added" pyproject.toml warn "$PY" "$PY
[dependency-groups]
dev = [\"pytest\"]"
t "requirements.txt: pin changed" requirements.txt warn 'flask==3.0.0' 'flask==3.1.0'
t "requirements.txt: comment only" requirements.txt quiet 'flask==3.0.0' '# pinned
flask==3.0.0'
t "docs updated in the same change: no warning" pom.xml quiet "$POM" "${POM/<\/dependencies>/<dependency><groupId>x</groupId><artifactId>y</artifactId></dependency></dependencies>}" AGENTS.md

echo; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
