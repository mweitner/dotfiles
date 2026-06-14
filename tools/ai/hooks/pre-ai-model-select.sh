#!/usr/bin/env bash
# Example git hook that runs before committing to ask for model selection
# Place or symlink this script to `.git/hooks/pre-commit` and `chmod +x` it.
# AI_HOOK_ID: pre-ai-model-select-v1

set -euo pipefail

# Determine repository root
ROOT=$(git rev-parse --show-toplevel)

# Task to select for this repository / hook
TASK="complex_markdown_fix"

echo "Running AI model selection for task: ${TASK}"

# Run the helper. It will prompt the user if needed. If user cancels, we abort.
MODEL=$(python3 "${ROOT}/tools/ai/select_model.py" --task "${TASK}") || {
  echo "Model selection cancelled; aborting commit." >&2
  exit 1
}

echo "Model chosen: ${MODEL}"

# Optionally export MODEL for downstream hooks or tooling
export AI_SELECTED_MODEL="${MODEL}"

# Continue commit
exit 0
