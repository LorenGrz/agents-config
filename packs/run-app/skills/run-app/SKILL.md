---
name: run-app
description: Launch the project and verify a change in the real running app, not only with tests. Use for "levantá la app", "corré la app", "probalo", "sacá un screenshot", "smoke test", "run the app", "start the server", "see it working", "take a screenshot". Reads the run command from AGENTS.md, starts it in the background, waits until it is healthy, then drives or probes it.
---

# Run the app

1. **Find the commands** in `AGENTS.md` (Commands table: dev/run) and the ports/env in the README or `.env.example`. Never invent a command. Do not start paid or shared external resources (cloud databases, deploys); use local containers or ask first.
2. **Start it in the background** and wait for readiness instead of sleeping: poll the health endpoint or the port until it answers (a Spring app: `/actuator/health`; a Node/Vite app: the dev server port; a Python app: its health route or port). Read the log if it does not come up.
3. **Exercise the change**:
   - Web UI: drive it headless with the Playwright MCP tools or a small Playwright script; take a screenshot of the affected screen at the smallest and largest supported widths. Screens behind login need a real session: ask for credentials or a test account, never guess or bypass auth.
   - HTTP API: call the endpoints with `curl` (happy path, a validation error, a not-found) and compare with the expected contract.
   - CLI or worker: run it with sample input and check the output and exit code.
4. **Report** what ran, the evidence (status codes, output, screenshot paths) and anything not verified. Stop the background process when done.
