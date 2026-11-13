# .gitignore gate

Read when: before the first commit in a repo, or when creating or auditing a `.gitignore`.

Minimum coverage:

- dependencies: `node_modules/`, `.pnp*`, `.venv/`, `venv/`, `__pycache__/`, `*.py[cod]`
- env & secrets: `.env`, `.env.*` (but `!.env.example`), `*.pem`, `*.key`, `*credentials*.json`, `*secret*.json`
- build output: `dist/`, `build/`, `out/`, `.next/`, `.turbo/`, `coverage/`, `*.tsbuildinfo`
- logs & caches: `*.log`, `.cache/`, `tmp/`
- OS/editor: `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/*` (but `!.vscode/extensions.json`)

Base it on the github/gitignore template for the stack.
