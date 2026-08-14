#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wf-record-audio-selftest.sh [options]

Quick diagnostic for wf-record audio inputs (desktop monitor + microphone).
It prints detected sources and performs optional short audio captures.

Options:
  --duration <seconds>     Capture duration for each test recording (default: 3)
  --output-dir <dir>       Output directory for test wav files
                           (default: /tmp/wf-record-audio-selftest-<timestamp>)
  --no-capture             Only print source detection, skip ffmpeg test captures
  -h, --help               Show help

Environment overrides:
  WF_RECORD_AUDIO_DEVICE   Force desktop source (monitor)
  WF_RECORD_MIC_DEVICE     Force microphone source

Examples:
  wf-record-audio-selftest.sh
  WF_RECORD_MIC_DEVICE=alsa_input.usb-foo wf-record-audio-selftest.sh --duration 5
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

default_sink_monitor_source() {
  local sink monitor
  sink=$(pactl info 2>/dev/null | awk -F': ' '/^Default Sink:/ {print $2; exit}')
  [[ -n "$sink" ]] || return 1
  monitor="${sink}.monitor"
  if pactl list short sources 2>/dev/null | awk '{print $2}' | grep -Fxq "$monitor"; then
    echo "$monitor"
    return 0
  fi
  return 1
}

default_mic_source() {
  local source=""

  source=$(pactl info 2>/dev/null | awk -F': ' '/^Default Source:/ {print $2; exit}')
  if [[ -n "$source" && "$source" != *".monitor" ]]; then
    echo "$source"
    return 0
  fi

  source=$(pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/ {print $2; exit}')
  [[ -n "$source" ]] || return 1
  echo "$source"
  return 0
}

duration="3"
output_dir=""
no_capture="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      duration="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    --no-capture)
      no_capture="true"
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

require_cmd pactl
require_cmd ffmpeg

if [[ -z "$output_dir" ]]; then
  output_dir="/tmp/wf-record-audio-selftest-$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "$output_dir"

monitor_source="${WF_RECORD_AUDIO_DEVICE:-}"
if [[ -z "$monitor_source" ]]; then
  monitor_source=$(default_sink_monitor_source || true)
fi

mic_source="${WF_RECORD_MIC_DEVICE:-}"
if [[ -z "$mic_source" ]]; then
  mic_source=$(default_mic_source || true)
fi

echo "Audio source diagnostic"
echo "- monitor source: ${monitor_source:-<not detected>}"
echo "- microphone source: ${mic_source:-<not detected>}"
echo "- output dir: $output_dir"

if [[ "$no_capture" == "true" ]]; then
  echo "Source detection only (no capture requested)."
  exit 0
fi

if [[ -n "$monitor_source" ]]; then
  monitor_file="$output_dir/monitor-test.wav"
  echo "Capturing monitor test: $monitor_file"
  ffmpeg -hide_banner -loglevel error -y -f pulse -i "$monitor_source" \
    -t "$duration" -ac 1 -ar 16000 -c:a pcm_s16le "$monitor_file"
  echo "Created: $monitor_file"
else
  echo "Skip monitor capture (no monitor source detected)." >&2
fi

if [[ -n "$mic_source" ]]; then
  mic_file="$output_dir/mic-test.wav"
  echo "Capturing mic test: $mic_file"
  ffmpeg -hide_banner -loglevel error -y -f pulse -i "$mic_source" \
    -t "$duration" -ac 1 -ar 16000 -c:a pcm_s16le "$mic_file"
  echo "Created: $mic_file"
else
  echo "Skip mic capture (no microphone source detected)." >&2
fi

echo "Done. Play test files and verify both streams are present."
