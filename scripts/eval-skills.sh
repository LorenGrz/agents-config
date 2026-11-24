#!/usr/bin/env bash
# Run the skill trigger evals in evals/ (needs Claude Code >= 2.1.269).
# Extra args pass through to `claude plugin eval`, e.g. --case 'trigger-*'.
# Env: EVAL_RUNS (default 1), EVAL_MAX_COST (USD cap, default 2).
#
# Each case is a real, paid model session. The sandbox loads only this plugin,
# so trigger rates can be higher than in a real session with other plugins loaded.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# --ablation none: `tool_used: Skill` graders can't pass without the plugin, so
# in with/without mode they'd be excluded from the score. It also halves cost.
claude plugin eval . --ablation none --runs "${EVAL_RUNS:-1}" --max-cost-usd "${EVAL_MAX_COST:-2}" "$@"
