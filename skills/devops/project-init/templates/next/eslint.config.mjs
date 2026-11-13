import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";
import reactHooks from "eslint-plugin-react-hooks";
import reactYouMightNotNeedAnEffect from "eslint-plugin-react-you-might-not-need-an-effect";
import jsxA11y from "eslint-plugin-jsx-a11y";

// Written by the project-init skill - edit freely; re-running init.sh
// without --force will not touch this file again (see copy_template_tree).
//
// Zero-useEffect doctrine on top of create-next-app's own config: forced to
// 'error' below so setState-in-effect and derived-state-in-effect patterns
// fail `pnpm lint` instead of only warning. The typescript-eslint rules below
// (nextTs already registers the @typescript-eslint plugin, so we only add
// rules under its prefix - no extra typescript-eslint import/dependency
// needed) encode the typescript-code-quality doctrine the same way.
// See AGENTS.md for the full conventions.
const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  reactHooks.configs.flat["recommended-latest"],
  reactYouMightNotNeedAnEffect.configs.recommended,
  {
    files: ["**/*.{ts,tsx}"],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    // eslint-config-next already registers the jsx-a11y plugin (with only a
    // handful of rules at 'warn'); merge in the plugin's full recommended
    // rule set instead of its flat config object, which would try to
    // re-register the same plugin and throw "Cannot redefine plugin".
    rules: {
      ...jsxA11y.flatConfigs.recommended.rules,
      "react-hooks/set-state-in-effect": "error",
      "react-you-might-not-need-an-effect/no-derived-state": "error",
      "react-you-might-not-need-an-effect/no-chain-state-updates": "error",
      "react-you-might-not-need-an-effect/no-event-handler": "error",
      "react-you-might-not-need-an-effect/no-adjust-state-on-prop-change": "error",
      "react-you-might-not-need-an-effect/no-reset-all-state-on-prop-change": "error",
      "react-you-might-not-need-an-effect/no-pass-live-state-to-parent": "error",
      "react-you-might-not-need-an-effect/no-pass-data-to-parent": "error",
      "react-you-might-not-need-an-effect/no-external-store-subscription": "error",
      "react-you-might-not-need-an-effect/no-initialize-state": "error",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/no-misused-promises": "error",
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/switch-exhaustiveness-check": "error",
      "@typescript-eslint/no-unnecessary-condition": "error",
      eqeqeq: "error",
      "no-console": ["error", { allow: ["warn", "error"] }],
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
