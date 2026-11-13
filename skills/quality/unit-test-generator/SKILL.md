---
name: unit-test-generator
description: Use this skill when generating a unit test file for a specific function or module - covering happy paths, edge cases, and error handling in the project's existing test framework. For running an existing suite and fixing failures, use execute-test-suite instead.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  frameworks:
    - jest
    - vitest
    - pytest
    - mocha
    - junit
  triggers:
    - write tests for
    - generate unit tests
    - add test coverage
    - test this function
---

# Unit Test Generator

## Objective

Produce a complete, runnable test file for one unit of code, covering the paths that matter and the failures that are expected.

## Workflow

1. Detect the test framework from the project: `pnpm-lock.yaml` plus a `test` script, `vitest.config`, `jest.config`, `pytest.ini`/`pyproject.toml`, `pom.xml`. Never introduce a new framework.
2. Read the unit's inputs, outputs, branches, and external dependencies.
3. Generate at minimum: 2 happy-path tests, 2 edge cases (empty, null, boundary values), 1 error test.
4. Mock external dependencies (network, filesystem, clock, DB) at the boundary.
5. Name tests by behavior: `should <expected> when <condition>`.
6. Add a one-line comment on each block saying why the case matters.

## Output

- One test file, organized with `describe`/`it` or the framework equivalent, runnable without edits.

## Operating Rules

- Test observable behavior, not private implementation.
- Each test is independent and order-free.
- Do not weaken assertions or skip cases to make tests pass.
- Match the project's existing test file layout and naming.
- Treat a TypeScript typecheck failure in the test file as a failure to fix before finishing.
- Hand off to `execute-test-suite` for the run-and-fix loop.
