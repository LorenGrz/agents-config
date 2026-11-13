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

## Workflow

1. Detect the build tool from the project root (table below) and run its test command.
2. If it passes, report the command and outcome.
3. If it fails with exit code `1`, preserve the logs (Failure capture) and identify the smallest failing unit.
4. Make the smallest code or test change consistent with the project architecture.
5. Re-run the same failing command.
6. Repeat until the suite passes or the failure requires missing user input, credentials, services, or external dependencies.

## Rules

- Do not switch package managers.
- Do not install dependencies unless the user approves or the project workflow requires it and the environment allows it.
- Do not mask failures by skipping tests, weakening assertions, or deleting coverage checks.
- Prefer focused test commands after the first failure, then run the broader suite before finalizing.
- For TypeScript projects, treat typecheck failures as first-class test failures.
- When multiple ecosystems exist, run the suite closest to the changed files first, then broaden to the repository-level suite.

### Detection and commands

Use local wrappers and package scripts when available.

| In the project root | Command | Fallback only when no wrapper exists |
|---|---|---|
| `pnpm-lock.yaml` | `pnpm test` | |
| `package-lock.json`, or `package.json` without a pnpm lock (unless repository docs say otherwise) | `npm test` | |
| `gradlew` or `build.gradle(.kts)` | `./gradlew test` | `gradle test` |
| `mvnw` or `pom.xml` | `./mvnw test` | `mvn test` |

- Node (NestJS, React, Next.js, React Native): when `package.json` has more specific scripts (`test:unit`, `test:e2e`, `typecheck`, `lint`), run them with the same package manager: `pnpm run test:unit`, `npm run test:unit`.
- Next.js: also run the repository's lint and build scripts when they exist (`next build`; `next lint` only up to Next 15, it was removed in 16).
- React Native: prefer the repository's existing unit test, typecheck, lint, and platform check scripts. Do not run native build commands unless the environment is prepared and the task requires it.

### Failure capture

Capture the output before editing. `pipefail` keeps the test command's exit code instead of the one from `tee`:

```bash
set -o pipefail
<test-command> 2>&1 | tee /tmp/agent-test.log
tail -n 200 /tmp/agent-test.log
```

Reports to check when present: Gradle `build/reports/tests/test/index.html` and `build/test-results/test/`; Maven `target/surefire-reports/` and `target/failsafe-reports/`.
