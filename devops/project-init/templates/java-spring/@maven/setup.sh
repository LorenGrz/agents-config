#!/usr/bin/env bash
# Maven: add the Spotless plugin (google-java-format) to pom.xml. Env: DIR, INSTALL. Idempotent.
set -euo pipefail
POM="$DIR/pom.xml"
VER="3.11.0"
if grep -q "spotless-maven-plugin" "$POM"; then echo "pom.xml: spotless already present"; exit 0; fi
snippet="$(mktemp)"
cat > "$snippet" <<XML
			<plugin>
				<groupId>com.diffplug.spotless</groupId>
				<artifactId>spotless-maven-plugin</artifactId>
				<version>$VER</version>
				<configuration>
					<java>
						<googleJavaFormat/>
					</java>
				</configuration>
			</plugin>
XML
n="$(grep -n '</plugins>' "$POM" | tail -1 | cut -d: -f1)"
[ -n "$n" ] || { echo "pom.xml: no <plugins> block to extend" >&2; exit 1; }
sed -i "$((n - 1))r $snippet" "$POM"
rm -f "$snippet"
echo "pom.xml: added Spotless $VER"
