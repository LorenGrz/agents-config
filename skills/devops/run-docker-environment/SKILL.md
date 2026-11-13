---
name: run-docker-environment
description: Use this skill when an agent must verify Docker daemon availability on Linux Ubuntu, start a local docker-compose.yml or compose.yaml for development databases, and inspect container health and logs from the terminal.
metadata:
  version: "0.1.0"
  owner: "platform-automation"
  platforms:
    - linux
    - ubuntu
  tools:
    - docker
    - docker compose
  triggers:
    - docker daemon
    - docker-compose.yml
    - compose.yaml
    - development databases
---

# Run Docker Environment

## Objective

Prepare and validate local Docker infrastructure for development, especially database services declared in a project-local Compose file.

## Workflow

1. Verify Docker CLI availability:

   ```bash
   docker --version
   docker compose version
   ```

2. Check whether the Docker daemon is running:

   ```bash
   docker info
   ```

   If this fails with a daemon connection error, check service status:

   ```bash
   systemctl status docker
   ```

   On Ubuntu, start Docker only when appropriate for the user environment:

   ```bash
   sudo systemctl start docker
   ```

3. Locate the Compose file from the project root. Prefer files in this order:

   - `docker-compose.yml`
   - `docker-compose.yaml`
   - `compose.yml`
   - `compose.yaml`

4. Start the local development environment:

   ```bash
   docker compose up -d
   ```

   If a non-default file is selected:

   ```bash
   docker compose -f compose.yaml up -d
   ```

5. Inspect container state:

   ```bash
   docker compose ps
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```

6. For failed or unhealthy containers, capture diagnostics:

   ```bash
   docker compose logs --tail=200
   docker inspect --format='{{json .State.Health}}' <container_name>
   ```

7. For development databases, verify readiness before running migrations or backend tests:

   ```bash
   docker compose ps
   docker compose logs --tail=100 <service_name>
   ```

## Operating Rules

- Do not assume Docker is running; always verify it first.
- Do not use destructive cleanup commands such as `docker system prune`, `docker volume rm`, or `docker compose down -v` unless explicitly requested.
- Prefer `docker compose` over legacy `docker-compose`.
- If permissions fail with `permission denied` on `/var/run/docker.sock`, report that the user may need Docker group membership or `sudo`, then use the least invasive command that completes the task.
- After startup, confirm that required database ports and health checks are available before moving on to application commands.
- Do not assume a database is ready just because the container is running; check health status, logs, or a project-specific readiness command.
