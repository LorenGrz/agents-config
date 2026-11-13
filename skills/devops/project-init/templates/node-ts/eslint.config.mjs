import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'

// Written by the project-init skill - edit freely; re-running init.sh
// without --force will not touch this file again (see copy_template_tree).
//
// node-ts has no official generator, so this is the project's only ESLint
// config (not an override of a stock default). See AGENTS.md for the full
// conventions.
export default tseslint.config(
  { ignores: ['dist'] },
  {
    extends: [js.configs.recommended, tseslint.configs.recommendedTypeChecked],
    files: ['**/*.ts'],
    languageOptions: {
      globals: globals.node,
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
