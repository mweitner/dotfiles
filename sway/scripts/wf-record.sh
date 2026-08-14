#!/usr/bin/env bash
set -euo pipefail

DIR="${WF_RECORD_OUTPUT_DIR:-${XDG_VIDEOS_DIR:-$HOME/videos}/screencasts}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PID_FILE="$RUNTIME_DIR/wf-record.pid"
META_FILE="$RUNTIME_DIR/wf-record.path"
LOG_FILE="$RUNTIME_DIR/wf-record.log"
MIC_PID_FILE="$RUNTIME_DIR/wf-record-mic.pid"
MIC_META_FILE="$RUNTIME_DIR/wf-record-mic.path"
MIC_LOG_FILE="$RUNTIME_DIR/wf-record-mic.log"

usage() {
  cat <<'EOF'
Usage: wf-record.sh {region|full|region-audio|full-audio|stop|status}

Commands:
  region        Record an interactively selected screen region.
  full          Record the currently focused output.
  region-audio  Record a selected region including desktop audio.
  full-audio    Record the focused output including desktop audio.
  stop          Stop the active recording.
  status        Print recording state and target file.
EOF
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$1" "$2"
  fi
}

cleanup_stale_state() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE" "$META_FILE" "$MIC_PID_FILE" "$MIC_META_FILE"
    fi
  fi

  if [[ -f "$MIC_PID_FILE" ]]; then
    local mic_pid
    mic_pid=$(cat "$MIC_PID_FILE")
    if ! kill -0 "$mic_pid" 2>/dev/null; then
      rm -f "$MIC_PID_FILE" "$MIC_META_FILE"
    fi
  fi
}

is_recording() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

has_encoder() {
  local enc="$1"
  ffmpeg -hide_banner -encoders 2>/dev/null | awk '{print $2}' | grep -Fxq "$enc"
}

pick_video_encoder() {
  if has_encoder libx264; then
    echo "libx264"
    return
  fi
  if has_encoder libopenh264; then
    echo "libopenh264"
    return
  fi
  if has_encoder mpeg4; then
    echo "mpeg4"
    return
  fi
  echo ""
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

wait_for_pid_exit() {
  local pid="$1"
  local retries="${2:-50}"

  while kill -0 "$pid" 2>/dev/null && (( retries > 0 )); do
    sleep 0.1
    retries=$((retries - 1))
  done
}

start_mic_capture() {
  local mic_source="$1"
  local mic_file="$2"

  setsid ffmpeg -hide_banner -loglevel error -y \
    -f pulse -i "$mic_source" -ac 1 -ar 48000 -c:a pcm_s16le "$mic_file" \
    >"$MIC_LOG_FILE" 2>&1 < /dev/null &
  echo "$!" > "$MIC_PID_FILE"
  echo "$mic_file" > "$MIC_META_FILE"
}

mix_recording_with_mic() {
  local output_file="$1"
  local mic_file="$2"
  local mixed_file

  [[ -f "$output_file" ]] || return 1
  [[ -s "$mic_file" ]] || return 1

  mixed_file="${output_file%.mp4}.mixed.mp4"
  ffmpeg -hide_banner -loglevel error -y \
    -i "$output_file" -i "$mic_file" \
    -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0:weights='1 1'[aout]" \
    -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k "$mixed_file"

  mv -f "$mixed_file" "$output_file"
}

start_recording() {
  local mode="$1"
  local with_audio="$2"
  local geometry=""
  local focused_output=""
  local video_codec=""
  local audio_device=""
  local mic_source=""
  local mic_file=""
  local include_mic="${WF_RECORD_INCLUDE_MIC:-1}"
  local output_file
  local -a cmd

  require_cmd wf-recorder
  require_cmd ffmpeg
  require_cmd notify-send

  cleanup_stale_state
  rm -f "$MIC_PID_FILE" "$MIC_META_FILE"
  if is_recording; then
    echo "A recording is already running." >&2
    notify "Screen recording" "A recording is already running. Stop it first."
    exit 1
  fi

  mkdir -p "$DIR"
  output_file="$DIR/screencast_${mode}_$(date +%Y%m%d_%H%M%S).mp4"

  cmd=(wf-recorder --file="$output_file" --framerate "${WF_RECORD_FPS:-30}" --overwrite)

  # Allow optional codec override; otherwise prefer widely playable H264 encoders.
  if [[ -n "${WF_RECORD_CODEC:-}" ]]; then
    cmd+=(--codec "$WF_RECORD_CODEC")
  else
    video_codec=$(pick_video_encoder)
    [[ -n "$video_codec" ]] && cmd+=(--codec "$video_codec")
  fi

  # Keep an optional pixel format override for upload compatibility tweaks.
  if [[ -n "${WF_RECORD_PIXEL_FORMAT:-}" ]]; then
    cmd+=(--pixel-format "$WF_RECORD_PIXEL_FORMAT")
  fi

  if [[ "$mode" == "region" ]]; then
    require_cmd slurp
    geometry=$(slurp)
    [[ -n "$geometry" ]] || exit 1
    cmd+=(--geometry "$geometry")
  else
    require_cmd swaymsg

    if command -v jq >/dev/null 2>&1; then
      focused_output=$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' | head -n1)
    else
      focused_output=$(swaymsg -t get_outputs 2>/dev/null | awk '/^Output / {name=$2} /focused yes/ {print name; exit}')
    fi

    if [[ -z "$focused_output" || "$focused_output" == "null" ]]; then
      echo "Could not determine focused output for full recording." >&2
      notify "Screen recording" "Could not determine focused output."
      exit 1
    fi

    cmd+=(--output "$focused_output")
  fi

  if [[ "$with_audio" == "true" ]]; then
    if [[ -n "${WF_RECORD_AUDIO_DEVICE:-}" ]]; then
      audio_device="$WF_RECORD_AUDIO_DEVICE"
    else
      audio_device=$(default_sink_monitor_source || true)
    fi

    if [[ -n "$audio_device" ]]; then
      cmd+=(--audio="$audio_device")
    else
      cmd+=(--audio)
    fi
  fi

  setsid "${cmd[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
  echo "$!" > "$PID_FILE"
  echo "$output_file" > "$META_FILE"

  if [[ "$with_audio" == "true" && "$include_mic" != "0" ]]; then
    if [[ -n "${WF_RECORD_MIC_DEVICE:-}" ]]; then
      mic_source="$WF_RECORD_MIC_DEVICE"
    else
      mic_source=$(default_mic_source || true)
    fi

    if [[ -n "$mic_source" ]]; then
      mic_file="$RUNTIME_DIR/wf-record-mic-$(date +%Y%m%d_%H%M%S).wav"
      if ! start_mic_capture "$mic_source" "$mic_file"; then
        notify "Screen recording" "Could not start microphone side capture."
      fi
    else
      notify "Screen recording" "No microphone source detected for side capture."
    fi
  fi

  notify "Screen recording started" "Saving to $output_file"
  echo "$output_file"
}

stop_recording() {
  cleanup_stale_state
  if ! is_recording; then
    echo "No active recording." >&2
    notify "Screen recording" "No active recording."
    exit 1
  fi

  local pid
  local mic_pid=""
  local mic_file=""
  local output_file=""
  pid=$(cat "$PID_FILE")
  if [[ -f "$META_FILE" ]]; then
    output_file=$(cat "$META_FILE")
  fi

  kill -INT "$pid"

  if [[ -f "$MIC_PID_FILE" ]]; then
    mic_pid=$(cat "$MIC_PID_FILE")
    kill -INT "$mic_pid" 2>/dev/null || true
  fi

  wait_for_pid_exit "$pid" 80
  [[ -n "$mic_pid" ]] && wait_for_pid_exit "$mic_pid" 80

  if [[ -f "$MIC_META_FILE" ]]; then
    mic_file=$(cat "$MIC_META_FILE")
  fi

  if [[ -n "$output_file" && -n "$mic_file" && -f "$mic_file" ]]; then
    if ! mix_recording_with_mic "$output_file" "$mic_file"; then
      notify "Screen recording" "Mic mix failed. Keeping original audio track."
    fi
  fi

  if [[ -n "$mic_file" && -f "$mic_file" && "${WF_RECORD_KEEP_MIC_TRACK:-0}" != "1" ]]; then
    rm -f "$mic_file"
  fi

  rm -f "$PID_FILE"
  rm -f "$MIC_PID_FILE" "$MIC_META_FILE"
  notify "Screen recording stopped" "Saved to ${output_file:-the last target file}."
  [[ -n "$output_file" ]] && echo "$output_file"
}

status_recording() {
  cleanup_stale_state
  if is_recording; then
    echo "running"
    [[ -f "$META_FILE" ]] && cat "$META_FILE"
  else
    echo "stopped"
  fi
}

case "${1:-}" in
  region)
    start_recording region false
    ;;
  full)
    start_recording full false
    ;;
  region-audio)
    start_recording region true
    ;;
  full-audio)
    start_recording full true
    ;;
  stop)
    stop_recording
    ;;
  status)
    status_recording
    ;;
  *)
    usage
    exit 1
    ;;
esac
