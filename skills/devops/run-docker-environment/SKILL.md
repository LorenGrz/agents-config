---
name: run-docker-environment
description: Use this skill when an agent must verify Docker daemon availability on Linux (systemd), start a local docker-compose.yml or compose.yaml for development databases, and inspect container health and logs from the terminal.
metadata:
  version: "0.1.0"
  owner: "platform-automation"
  platforms:
    - linux
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

1. Verify the CLI and the daemon; never assume Docker is running:

   ```bash
   docker --version
   docker compose version
   docker info
   ```

   If `docker info` fails with a daemon connection error, check the service and start it only when appropriate for the user environment:

   ```bash
   systemctl status docker
   sudo systemctl start docker
   ```

2. Locate the Compose file from the project root. `docker compose` picks the first of these by itself:

   - `compose.yaml`
   - `compose.yml`
   - `docker-compose.yaml`
   - `docker-compose.yml`

3. Start the local development environment. Pass `-f` only when the file has another name or location, or when several of the names above exist and the intended one is not the first:

   ```bash
   docker compose up -d
   docker compose -f <file> up -d
   ```

4. Inspect container state:

   ```bash
   docker compose ps
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```

5. For failed or unhealthy containers, capture diagnostics:

   ```bash
   docker compose logs --tail=200
   docker compose logs --tail=100 <service_name>
   docker inspect --format='{{json .State.Health}}' <container_name>
   ```

6. For development databases, confirm the required ports and health checks before running migrations, backend tests or application commands. A running container is not a ready database: check health status, logs, or a project-specific readiness command.

## Rules

- Do not use destructive cleanup commands such as `docker system prune`, `docker volume rm`, or `docker compose down -v` unless explicitly requested.
- Prefer `docker compose` over legacy `docker-compose`.
- If permissions fail with `permission denied` on `/var/run/docker.sock`, report that the user may need Docker group membership or `sudo`, then use the least invasive command that completes the task.
