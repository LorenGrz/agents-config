#!/usr/bin/env bash
# Adds Spotless to a Gradle build (Groovy or Kotlin DSL). Env: DIR, INSTALL, LANGUAGE=java|kotlin.
# Idempotent. Spotless pin: keep in sync with the Maven variant.
set -euo pipefail
VER="8.11.0"
if [ -f "$DIR/build.gradle.kts" ]; then F="$DIR/build.gradle.kts"; DSL=kts
elif [ -f "$DIR/build.gradle" ]; then F="$DIR/build.gradle"; DSL=groovy
else echo "no build.gradle[.kts] in $DIR" >&2; exit 1; fi

if grep -q "com.diffplug.spotless" "$F"; then echo "$(basename "$F"): spotless already present"; exit 0; fi

if [ "$DSL" = kts ]; then
  plugin="	id(\"com.diffplug.spotless\") version \"$VER\""
  case "$LANGUAGE" in java) fmt='googleJavaFormat()' ;; kotlin) fmt='ktlint()' ;; esac
  block=$'\nspotless {\n\t'"$LANGUAGE"$' {\n\t\t'"$fmt"$'\n\t}\n}'
else
  plugin="	id 'com.diffplug.spotless' version '$VER'"
  case "$LANGUAGE" in java) fmt='googleJavaFormat()' ;; kotlin) fmt='ktlint()' ;; esac
  block=$'\nspotless {\n\t'"$LANGUAGE"$' {\n\t\t'"$fmt"$'\n\t}\n}'
fi
# first line of the plugins block, then the config block at the end
tmp="$(mktemp)"
awk -v p="$plugin" '{ print } /^plugins[[:space:]]*\{/ && !d { print p; d=1 }' "$F" > "$tmp"
printf '%s\n' "$block" >> "$tmp"
mv "$tmp" "$F"
echo "$(basename "$F"): added Spotless $VER ($LANGUAGE)"
