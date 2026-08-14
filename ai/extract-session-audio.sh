#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: extract-session-audio.sh <session-dir> [options]

Extract audio from all matching MP4 session parts.

Options:
  --format <wav|mp3>       Output audio format (default: wav)
  --sample-rate <hz>       Output sample rate (default: 16000)
  --channels <count>       Output channel count (default: 1)
  --pattern <glob>         Input file glob (default: *.mp4)
  --output-dir <dir>       Output directory (default: session-dir)
  --overwrite              Replace existing output files
  -h, --help               Show help

Examples:
  extract-session-audio.sh "$HOME/videos/screencasts/teams-2026-08-13-lpo" \
    --format wav --sample-rate 16000 --channels 1

  extract-session-audio.sh "$HOME/videos/screencasts/teams-2026-08-13-lpo" \
    --format mp3 --pattern '*part*.mp4' --output-dir ./audio
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

session_dir=""
format="wav"
sample_rate="16000"
channels="1"
pattern="*.mp4"
output_dir=""
overwrite="false"

if [[ "${1:-}" != -* ]]; then
  session_dir="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      format="${2:-}"
      shift 2
      ;;
    --sample-rate)
      sample_rate="${2:-}"
      shift 2
      ;;
    --channels)
      channels="${2:-}"
      shift 2
      ;;
    --pattern)
      pattern="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
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

[[ -n "$session_dir" ]] || { echo "Missing <session-dir>." >&2; usage; exit 1; }
[[ -d "$session_dir" ]] || { echo "Session dir not found: $session_dir" >&2; exit 1; }

case "$format" in
  wav|mp3) ;;
  *)
    echo "Unsupported format: $format (expected wav or mp3)" >&2
    exit 1
    ;;
esac

require_cmd ffmpeg

if [[ -z "$output_dir" ]]; then
  output_dir="$session_dir"
fi
mkdir -p "$output_dir"

shopt -s nullglob
files=("$session_dir"/$pattern)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No input files found: $session_dir/$pattern" >&2
  exit 1
fi

for input in "${files[@]}"; do
  base_name="$(basename "$input")"
  stem="${base_name%.*}"
  output="$output_dir/$stem.$format"

  if [[ -f "$output" && "$overwrite" != "true" ]]; then
    echo "Skip existing: $output"
    continue
  fi

  if [[ "$format" == "wav" ]]; then
    ffmpeg_args=(-vn -ac "$channels" -ar "$sample_rate")
  else
    ffmpeg_args=(-vn -ac "$channels" -ar "$sample_rate" -codec:a libmp3lame -q:a 2)
  fi

  echo "Extract: $input -> $output"
  ffmpeg -hide_banner -loglevel error -y -i "$input" "${ffmpeg_args[@]}" "$output"
done

echo "Done. Audio files are in: $output_dir"
