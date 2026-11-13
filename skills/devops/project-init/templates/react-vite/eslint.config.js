import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import reactYouMightNotNeedAnEffect from 'eslint-plugin-react-you-might-not-need-an-effect'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import tseslint from 'typescript-eslint'

// Written by the project-init skill - edit freely; re-running init.sh
// without --force will not touch this file again (see copy_template_tree).
//
// Zero-useEffect doctrine: react-hooks/set-state-in-effect and the
// react-you-might-not-need-an-effect rules are forced to 'error' below so
// setState-in-effect and derived-state-in-effect patterns fail `pnpm lint`
// instead of only warning. The typescript-eslint/jsx-a11y rules below encode
// the typescript-code-quality and react-component-validator doctrines the
// same way. See AGENTS.md for the full conventions.
export default tseslint.config(
  { ignores: ['dist'] },
  {
    extends: [
      js.configs.recommended,
      tseslint.configs.recommendedTypeChecked,
      reactHooks.configs.flat['recommended-latest'],
      reactYouMightNotNeedAnEffect.configs.recommended,
      jsxA11y.flatConfigs.recommended,
    ],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: {
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactRefresh.configs.vite.rules,
      'react-hooks/set-state-in-effect': 'error',
      'react-you-might-not-need-an-effect/no-derived-state': 'error',
      'react-you-might-not-need-an-effect/no-chain-state-updates': 'error',
      'react-you-might-not-need-an-effect/no-event-handler': 'error',
      'react-you-might-not-need-an-effect/no-adjust-state-on-prop-change': 'error',
      'react-you-might-not-need-an-effect/no-reset-all-state-on-prop-change': 'error',
      'react-you-might-not-need-an-effect/no-pass-live-state-to-parent': 'error',
      'react-you-might-not-need-an-effect/no-pass-data-to-parent': 'error',
      'react-you-might-not-need-an-effect/no-external-store-subscription': 'error',
      'react-you-might-not-need-an-effect/no-initialize-state': 'error',
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
