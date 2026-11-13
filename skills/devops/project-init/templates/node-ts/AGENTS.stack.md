## Node + TypeScript conventions

- Strict TypeScript (`strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch` in `tsconfig.json`), no `any`. Deeper: `typescript-code-quality`.
- Validate external input (env, CLI args, files, network) at the boundary before it reaches the rest of the code.
- Run with `tsx`; test with Vitest; lint with the provided `eslint.config.mjs`.
- Keep it minimal - this is a learning-stage project, not a framework. Follow `typescript-project-starter` for scope.
