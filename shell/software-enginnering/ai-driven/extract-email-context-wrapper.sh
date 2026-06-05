#!/usr/bin/env bash
set -euo pipefail

# Extract an email .eml file to markdown context using shared dotfiles tooling.
# This mirrors the local scripts pattern (e.g. render-plantuml-png.sh) while
# keeping shared extraction logic centralized in dotfiles.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_DEFAULT="$HOME/dotfiles/shell/software-enginnering/ai-driven/extract-email-context.py"
SHARED_SCRIPT="${EXTRACT_EMAIL_CONTEXT_SCRIPT:-$SHARED_DEFAULT}"

INPUT_EML="${1:-$ROOT_DIR/input/email.eml}"
OUTPUT_MD="${2:-$ROOT_DIR/source/_static/communication/email/context.md}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 command not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$SHARED_SCRIPT" ]]; then
  echo "Error: shared extractor script not found: $SHARED_SCRIPT" >&2
  echo "Hint: set EXTRACT_EMAIL_CONTEXT_SCRIPT to your shared script path." >&2
  exit 1
fi

if [[ ! -f "$INPUT_EML" ]]; then
  echo "Error: input .eml file not found: $INPUT_EML" >&2
  echo "Usage: $0 [input.eml] [output.md]" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_MD")"

python3 "$SHARED_SCRIPT" --input "$INPUT_EML" --output "$OUTPUT_MD"

echo "Email context extraction complete."
echo "- Input:  $INPUT_EML"
echo "- Output: $OUTPUT_MD"
