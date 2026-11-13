import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'

// Written by the project-init skill - edit freely; re-running init.sh
// without --force will not touch this file again (see copy_template_tree).
//
// `nest new` ships `oxlint` instead of ESLint (same as `pnpm create vite`).
// This flat config replaces it so the typescript-code-quality rules below
// actually run under `pnpm lint`. See AGENTS.md for the full conventions.
export default tseslint.config(
  { ignores: ['dist', 'node_modules'] },
  {
    extends: [js.configs.recommended, tseslint.configs.recommendedTypeChecked],
    files: ['**/*.ts'],
    languageOptions: {
      globals: globals.node,
      sourceType: 'module',
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/switch-exhaustiveness-check': 'error',
      '@typescript-eslint/no-unnecessary-condition': 'error',
      eqeqeq: 'error',
      'no-console': ['error', { allow: ['warn', 'error'] }],
    },
  },
)
