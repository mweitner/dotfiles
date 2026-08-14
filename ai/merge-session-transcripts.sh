#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: merge-session-transcripts.sh <session-dir> <session-id> [options]

Merge transcript part files into one canonical transcript in deterministic order.

Options:
  --pattern <glob>         Input file glob (default: *part*.txt)
  --output <file>          Output file path
  --no-part-separators     Do not add part separators in merged output
  --overwrite              Replace output file if it exists
  -h, --help               Show help

Examples:
  merge-session-transcripts.sh "$HOME/videos/screencasts/s1" teams-2026-08-13-lpo

  merge-session-transcripts.sh "$HOME/videos/screencasts/s1" teams-2026-08-13-lpo \
    --pattern '*.wav.txt' --output "$HOME/tmp/merged.txt" --overwrite
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

session_dir="$1"
session_id="$2"
shift 2

pattern="*part*.txt"
output=""
with_separators="true"
overwrite="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --no-part-separators)
      with_separators="false"
      shift
      ;;
    --overwrite)
      overwrite="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

[[ -d "$session_dir" ]] || { echo "Session dir not found: $session_dir" >&2; exit 1; }

if [[ -z "$output" ]]; then
  output="$session_dir/$session_id-merged-transcript.txt"
fi

if [[ -f "$output" && "$overwrite" != "true" ]]; then
  echo "Output exists: $output (use --overwrite to replace)" >&2
  exit 1
fi

shopt -s nullglob
files=("$session_dir"/$pattern)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No transcript files found: $session_dir/$pattern" >&2
  exit 1
fi

# Keep merge order stable and natural for part numbers.
IFS=$'\n' sorted=( $(printf '%s\n' "${files[@]}" | sort -V) )
unset IFS

mkdir -p "$(dirname "$output")"
: > "$output"

for f in "${sorted[@]}"; do
  if [[ "$with_separators" == "true" ]]; then
    {
      echo
      echo "---"
      echo "SourcePart: $(basename "$f")"
      echo
    } >> "$output"
  fi

  cat "$f" >> "$output"
  echo >> "$output"
done

echo "Merged ${#sorted[@]} parts into: $output"
