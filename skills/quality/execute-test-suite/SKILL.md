---
name: execute-test-suite
description: Use this skill when an agent must detect npm, pnpm, Gradle, or Maven projects, run the correct test suite for NestJS, React, Kotlin, or Spring Boot, capture failing console logs, and enter an automated correction loop after exit code 1.
metadata:
  version: "0.1.0"
  owner: "platform-automation"
  platforms:
    - linux
    - ubuntu
  ecosystems:
    - node
    - npm
    - pnpm
    - gradle
    - maven
  triggers:
    - test suite
    - npm test
    - pnpm test
    - gradle test
    - maven test
    - exit 1
---

# Execute Test Suite

## Objective

Detect the current project's build tool, run the appropriate tests, and use failure logs to drive an automatic fix-and-retest loop.

## Project Detection

Inspect the project root before running tests:

- `pnpm-lock.yaml` indicates pnpm.
- `package-lock.json` indicates npm.
- `package.json` without pnpm lock usually uses npm unless repository docs say otherwise.
- `gradlew` or `build.gradle(.kts)` indicates Gradle.
- `mvnw` or `pom.xml` indicates Maven.

When multiple ecosystems exist, run the suite closest to the changed files first, then broaden to the repository-level suite.

## Commands

Use local wrappers and package scripts when available.

### Node, NestJS, React, Next.js, React Native

Prefer pnpm when `pnpm-lock.yaml` exists:

```bash
pnpm test
```

Use npm when `package-lock.json` exists or no pnpm lock exists:

```bash
npm test
```

If scripts reveal more specific commands, use them:

```bash
npm run test
npm run test:unit
npm run test:e2e
pnpm run test
pnpm run test:unit
pnpm run test:e2e
npm run typecheck
npm run lint
pnpm run typecheck
pnpm run lint
```

For Next.js projects, also run `next lint`, `next build`, or the repository's equivalent scripts when they exist.

For React Native projects, prefer the repository's existing unit test, typecheck, lint, and platform check scripts. Do not run native build commands unless the environment is prepared and the task requires it.

### Kotlin, Spring Boot, Gradle

Prefer the project wrapper:

```bash
./gradlew test
```

Fallback only when no wrapper exists:

```bash
gradle test
```

### Kotlin, Spring Boot, Maven

Prefer the project wrapper:

```bash
./mvnw test
```

Fallback only when no wrapper exists:

```bash
mvn test
```

## Failure Capture

When a test command exits with code `1`, capture the relevant error output before editing:

```bash
<test-command> 2>&1 | tee /tmp/agent-test.log
```

Then inspect the failure:

```bash
tail -n 200 /tmp/agent-test.log
```

For Gradle, also check generated reports when present:

- `build/reports/tests/test/index.html`
- `build/test-results/test/`

For Maven, check:

- `target/surefire-reports/`
- `target/failsafe-reports/`

## Automatic Correction Loop

1. Run the detected test command.
2. If it passes, report the command and outcome.
3. If it fails with exit code `1`, preserve the logs and identify the smallest failing unit.
4. Make the smallest code or test change consistent with the project architecture.
5. Re-run the same failing command.
6. Repeat until the suite passes or the failure requires missing user input, credentials, services, or external dependencies.

## Operating Rules

- Do not switch package managers.
- Do not install dependencies unless the user approves or the project workflow requires it and the environment allows it.
- Do not mask failures by skipping tests, weakening assertions, or deleting coverage checks.
- Prefer focused test commands after the first failure, then run the broader suite before finalizing.
- For TypeScript projects, treat typecheck failures as first-class test failures.
