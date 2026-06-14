#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <repo-root> [topic-slug] [--append]" >&2
  echo "Example (new file): $0 /home/ldcwem0/dps-dev lpo-komm-schnittstelle" >&2
  echo "Example (append):  $0 /home/ldcwem0/dps-dev lpo-komm-schnittstelle --append" >&2
}

format_markdown() {
  local target_file="$1"

  python3 - "$target_file" <<'PY'
import pathlib
import re
import sys
import textwrap

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = text.splitlines()

width = 119
result = []
in_code_block = False

def wrap_paragraph(prefix: str, body: str) -> list[str]:
  available = width - len(prefix)
  if available < 20:
    return [prefix + body]
  wrapped = textwrap.wrap(
    body,
    width=available,
    break_long_words=False,
    break_on_hyphens=False,
    drop_whitespace=True,
  )
  if not wrapped:
    return [prefix.rstrip()]
  if len(wrapped) == 1:
    return [prefix + wrapped[0]]
  hanging = " " * len(prefix)
  return [prefix + wrapped[0], *[hanging + part for part in wrapped[1:]]]

for line in lines:
  if line.startswith("```"):
    result.append(line)
    in_code_block = not in_code_block
    continue

  if in_code_block:
    result.append(line)
    continue

  if not line.strip():
    result.append("")
    continue

  if line.lstrip().startswith("|"):
    result.append(line)
    continue

  if re.match(r"^\s*[-*+]\s+", line):
    match = re.match(r"^(\s*[-*+]\s+)(.*)$", line)
    assert match is not None
    result.extend(wrap_paragraph(match.group(1), match.group(2)))
    continue

  if re.match(r"^\s*>\s?", line):
    match = re.match(r"^(\s*>\s?)(.*)$", line)
    assert match is not None
    result.extend(wrap_paragraph(match.group(1), match.group(2).lstrip()))
    continue

  if re.match(r"^\s*\d+[.)]\s+", line):
    match = re.match(r"^(\s*\d+[.)]\s+)(.*)$", line)
    assert match is not None
    result.extend(wrap_paragraph(match.group(1), match.group(2)))
    continue

  indent = len(line) - len(line.lstrip(" "))
  prefix = " " * indent
  body = line[indent:]
  result.extend(wrap_paragraph(prefix, body))

path.write_text("\n".join(result) + "\n", encoding="utf-8")
PY
}

append_mode=0
positionals=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --append)
      append_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -* )
      echo "Error: unknown option $1" >&2
      usage
      exit 1
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if [ "${#positionals[@]}" -lt 1 ]; then
  usage
  exit 1
fi

REPO_ROOT="${positionals[0]}"
TOPIC="${positionals[1]:-general}"

if [ ! -d "$REPO_ROOT" ]; then
  echo "Error: repo root does not exist: $REPO_ROOT" >&2
  exit 1
fi

if command -v wl-paste >/dev/null 2>&1; then
  CHAT_MD="$(wl-paste --no-newline)"
elif command -v xclip >/dev/null 2>&1; then
  CHAT_MD="$(xclip -o -selection clipboard)"
elif command -v xsel >/dev/null 2>&1; then
  CHAT_MD="$(xsel --clipboard --output)"
else
  echo "Error: no clipboard reader found (wl-paste/xclip/xsel)." >&2
  exit 1
fi

CHAT_MD="$(printf '%s' "$CHAT_MD" | sed 's/\r$//')"

if [ -z "$(printf '%s' "$CHAT_MD" | tr -d '[:space:]')" ]; then
  echo "Error: clipboard is empty. Copy bookmarklet output first." >&2
  exit 1
fi

DATE_STAMP="$(date +%Y-%m-%d)"
SAFE_TOPIC="$(printf '%s' "$TOPIC" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
if [ -z "$SAFE_TOPIC" ]; then
  SAFE_TOPIC="general"
fi

OUT_DIR="$REPO_ROOT/docs/ai-context"
OUT_FILE="$OUT_DIR/teams-sync-$DATE_STAMP-$SAFE_TOPIC.md"

mkdir -p "$OUT_DIR"

if [ "$append_mode" -eq 1 ] && [ -f "$OUT_FILE" ]; then
  {
    echo
    echo "---"
    echo
    echo "CapturedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    printf '%s\n' "$CHAT_MD"
  } >> "$OUT_FILE"
else
  {
    echo "# Teams Sync $DATE_STAMP"
    echo
    echo "Source: Microsoft Teams web bookmarklet export"
    echo "Topic: $SAFE_TOPIC"
    echo "CapturedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "---"
    echo "<!-- markdownlint-disable MD013 -->"
    echo
    echo
    printf '%s\n' "$CHAT_MD"
  } > "$OUT_FILE"
fi

format_markdown "$OUT_FILE"

echo "Saved: $OUT_FILE"
