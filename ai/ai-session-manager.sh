#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ai-session-manager.sh <command> [options]

Manage AI project workflows with active project and active session context.

Commands:
  prepare [project-name] [session-name]
                                  Initialize project/session and activate context
  screencast start [project] [session]
                                  Start recording in active/default context
  screencast stop [project] [session]
                                  Stop recording and persist output file
  screencast next [project] [session]
                                  Stop current recording and start next
  status [project] [session]      Show active context and recording state
  create-minutes [options]        Extract audio, create transcript placeholders, generate minutes
  update-minutes [options]        Alias for create-minutes (idempotent re-run)
  paths                            Show resolved config/state/cache/runtime paths
  doctor                           Check writable directories and state file health
  project activate <name> [session]
                                  Activate project context (session optional)
  project clear                    Clear persisted context
  session activate [name]          Activate session within active project
  list [project]                   List all projects and sessions, or one project

create-minutes / update-minutes options:
  --title <text>                  Meeting title (default: "<project> <session>")
  --owner <name>                  Default owner in minutes skeleton
  --date <YYYY-MM-DD>             Meeting date (default: today)
  --asr                           Use whisper-cli for transcripts instead of placeholders
                                  (requires whisper-cli and ~/models/ggml-large-v3.bin)
  --overwrite                     Overwrite existing audio and transcript files
  --force-minutes                 Overwrite existing minutes skeleton file

Environment:
  AI_SESSION_DIR                  Override session artifacts directory (default: ~/.ai-sessions)
  AI_SESSION_STATE_FILE           Override state file path
  AI_PROJECT                      Shell-level active project context override
  AI_SESSION                      Shell-level active session context override
  XDG_CONFIG_HOME                 Config base dir (default: ~/.config)
  XDG_STATE_HOME                  State base dir (default: ~/.local/state)
  XDG_CACHE_HOME                  Cache base dir (default: ~/.cache)
  XDG_RUNTIME_DIR                 Runtime base dir (default: /tmp)

Defaults:
  project: current month (yyyy.MM)
  session: current day (yyyy.MM.dd)
  mode:    flat naming for implicit default project; part naming for named projects

Examples:
  ai-session-manager.sh prepare myproject teams-sync-1
  ai-session-manager.sh prepare myproject
  ai-session-manager.sh prepare
  ai-session-manager.sh screencast start
  ai-session-manager.sh screencast next
  AI_PROJECT=myproject AI_SESSION=teams-sync-2 ai-session-manager.sh screencast start
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing command: $1" >&2
    exit 1
  fi
}

SESSION_BASE_DIR="${AI_SESSION_DIR:-$HOME/.ai-sessions}"
APP_NAME="ai-session-manager"
CONFIG_BASE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_BASE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_BASE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
RUNTIME_BASE_DIR="${XDG_RUNTIME_DIR:-/tmp}"

CONFIG_DIR="$CONFIG_BASE_DIR/$APP_NAME"
STATE_DIR="$STATE_BASE_DIR/$APP_NAME"
CACHE_DIR="$CACHE_BASE_DIR/$APP_NAME"
RUNTIME_DIR="$RUNTIME_BASE_DIR/$APP_NAME"

STATE_FILE_DEFAULT="$STATE_DIR/session.state"
SESSION_STATE_FILE="${AI_SESSION_STATE_FILE:-$STATE_FILE_DEFAULT}"

RECORDER_SCRIPT="$HOME/.config/sway/scripts/wf-record.sh"
RECORDER_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
RECORDER_PID_FILE="$RECORDER_RUNTIME_DIR/wf-record.pid"

mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$CACHE_DIR" "$RUNTIME_DIR"

default_project_name() {
  date +%Y.%m
}

default_session_name() {
  date +%Y.%m.%d
}

load_session_state() {
  if [[ -f "$SESSION_STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SESSION_STATE_FILE"
  fi

  : "${CURRENT_PROJECT:=}"
  : "${CURRENT_AI_SESSION:=}"
  : "${PROJECT_FOLDER:=}"
  : "${SESSION_FOLDER:=}"
  : "${OUTPUT_NAMING:=named}"
  : "${CURRENT_PART:=1}"
  : "${RECORDING_PID:=}"
  : "${LAST_OUTPUT_FILE:=}"
}

save_session_state() {
  local state_target_dir
  state_target_dir="$(dirname "$SESSION_STATE_FILE")"
  mkdir -p "$state_target_dir"

  local tmp_file
  tmp_file="$(mktemp "$state_target_dir/session.state.XXXXXX")"

  cat > "$tmp_file" <<EOF
CURRENT_PROJECT="$CURRENT_PROJECT"
CURRENT_AI_SESSION="$CURRENT_AI_SESSION"
PROJECT_FOLDER="$PROJECT_FOLDER"
SESSION_FOLDER="$SESSION_FOLDER"
OUTPUT_NAMING="$OUTPUT_NAMING"
CURRENT_PART="$CURRENT_PART"
RECORDING_PID="${RECORDING_PID:-}"
LAST_OUTPUT_FILE="${LAST_OUTPUT_FILE:-}"
EOF

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$SESSION_STATE_FILE"
}

clear_session_state() {
  rm -f "$SESSION_STATE_FILE"
}

render_prompt_template() {
  local template_path="$1"
  local output_path="$2"
  local project_name="$3"
  local session_name="$4"
  local transcript_path="$5"
  local notes_path="$6"

  local template_text
  template_text="$(cat "$template_path")"

  template_text="${template_text//\{\{project_name\}\}/$project_name}"
  template_text="${template_text//\{\{session_name\}\}/$session_name}"
  template_text="${template_text//\{\{transcript_path\}\}/$transcript_path}"
  template_text="${template_text//\{\{notes_path\}\}/$notes_path}"

  printf '%s' "$template_text" > "$output_path"
}

populate_prompt_templates() {
  local project_name="$1"
  local session_name="$2"
  local prompt_dir="$SESSION_FOLDER/ai-prompt-engineering"
  local template_dir="${AI_SESSION_TEMPLATE_DIR:-$HOME/.ai-sessions/templates}"
  local transcript_path="$SESSION_FOLDER/${project_name}-${session_name}-merged-transcript.txt"
  local notes_path="$SESSION_FOLDER/${project_name}-${session_name}-meeting-minutes.md"

  mkdir -p "$prompt_dir"

  if [[ -f "$template_dir/meeting-minutes-refine.long.md" ]]; then
    render_prompt_template \
      "$template_dir/meeting-minutes-refine.long.md" \
      "$prompt_dir/${project_name}-${session_name}-minutes-refine.long.md" \
      "$project_name" "$session_name" "$transcript_path" "$notes_path"
  fi

  if [[ -f "$template_dir/meeting-minutes-refine.short.md" ]]; then
    render_prompt_template \
      "$template_dir/meeting-minutes-refine.short.md" \
      "$prompt_dir/${project_name}-${session_name}-minutes-refine.short.md" \
      "$project_name" "$session_name" "$transcript_path" "$notes_path"
  fi

  echo "Prompt templates generated in: $prompt_dir"
  echo "  - ${project_name}-${session_name}-minutes-refine.long.md"
  echo "  - ${project_name}-${session_name}-minutes-refine.short.md"
}

list_projects() {
  local project_filter="${1:-}"
  local project_dir
  local found=0

  shopt -s nullglob
  local project_dirs=("$SESSION_BASE_DIR"/*)
  shopt -u nullglob

  if [[ ${#project_dirs[@]} -eq 0 ]]; then
    echo "No projects found under $SESSION_BASE_DIR"
    return 0
  fi

  for project_dir in "${project_dirs[@]}"; do
    [[ -d "$project_dir" ]] || continue
    local project_name
    project_name="$(basename "$project_dir")"

    if [[ "$project_name" == "templates" ]]; then
      continue
    fi

    if [[ -n "$project_filter" && "$project_name" != "$project_filter" ]]; then
      continue
    fi

    found=1
    echo "Project: $project_name"

    shopt -s nullglob
    local session_dirs=("$project_dir"/*)
    shopt -u nullglob

    if [[ ${#session_dirs[@]} -eq 0 ]]; then
      echo "  (no sessions)"
      continue
    fi

    for session_dir in "${session_dirs[@]}"; do
      [[ -d "$session_dir" ]] || continue
      echo "  - $(basename "$session_dir")"
    done
  done

  if [[ $found -eq 0 ]]; then
    if [[ -n "$project_filter" ]]; then
      echo "Project not found: $project_filter"
      return 1
    fi
    echo "No projects found under $SESSION_BASE_DIR"
    return 1
  fi
}

print_paths() {
  echo "APP_NAME=$APP_NAME"
  echo "SESSION_BASE_DIR=$SESSION_BASE_DIR"
  echo "CONFIG_DIR=$CONFIG_DIR"
  echo "STATE_DIR=$STATE_DIR"
  echo "CACHE_DIR=$CACHE_DIR"
  echo "RUNTIME_DIR=$RUNTIME_DIR"
  echo "SESSION_STATE_FILE=$SESSION_STATE_FILE"
  echo "RECORDER_PID_FILE=$RECORDER_PID_FILE"
}

doctor() {
  local errors=0
  echo "AI Session Manager Doctor"
  echo "-------------------------"
  print_paths
  echo

  for d in "$SESSION_BASE_DIR" "$CONFIG_DIR" "$STATE_DIR" "$CACHE_DIR" "$RUNTIME_DIR"; do
    if [[ -d "$d" ]]; then
      if [[ -w "$d" ]]; then
        echo "[OK] writable dir: $d"
      else
        echo "[ERR] not writable: $d"
        errors=$((errors + 1))
      fi
    else
      if mkdir -p "$d" 2>/dev/null; then
        echo "[OK] created dir: $d"
      else
        echo "[ERR] cannot create dir: $d"
        errors=$((errors + 1))
      fi
    fi
  done

  if [[ -f "$SESSION_STATE_FILE" ]]; then
    if [[ -r "$SESSION_STATE_FILE" && -w "$SESSION_STATE_FILE" ]]; then
      echo "[OK] state file readable+writable: $SESSION_STATE_FILE"
    else
      echo "[ERR] state file permission issue: $SESSION_STATE_FILE"
      errors=$((errors + 1))
    fi
  else
    echo "[INFO] state file does not exist yet: $SESSION_STATE_FILE"
  fi

  echo
  if [[ $errors -eq 0 ]]; then
    echo "Doctor result: healthy"
  else
    echo "Doctor result: $errors issue(s) found"
    return 1
  fi
}

recorder_status() {
  bash "$RECORDER_SCRIPT" status 2>/dev/null | sed -n '1p'
}

recorder_output_file() {
  bash "$RECORDER_SCRIPT" status 2>/dev/null | sed -n '2p'
}

recorder_is_running() {
  [[ "$(recorder_status)" == "running" ]]
}

cleanup_orphan_mic_capture() {
  local mic_pid_file="$RECORDER_RUNTIME_DIR/wf-record-mic.pid"
  local mic_meta_file="$RECORDER_RUNTIME_DIR/wf-record-mic.path"
  local mic_pid=""
  local orphan_mic_file=""

  if [[ -f "$mic_meta_file" ]]; then
    orphan_mic_file="$(cat "$mic_meta_file")"
  fi

  if [[ -f "$mic_pid_file" ]]; then
    mic_pid="$(cat "$mic_pid_file")"
    if [[ -n "$mic_pid" ]] && kill -0 "$mic_pid" 2>/dev/null; then
      kill -INT "$mic_pid" 2>/dev/null || true
      for _ in {1..30}; do
        kill -0 "$mic_pid" 2>/dev/null || break
        sleep 0.1
      done
    fi
  fi

  rm -f "$mic_pid_file" "$mic_meta_file"

  if [[ -n "$orphan_mic_file" && -f "$orphan_mic_file" ]]; then
    echo "warning: recovered orphan mic track: $orphan_mic_file" >&2
  fi
}

next_part_number() {
  local session_folder="$1"
  local project_name="$2"
  local session_name="$3"
  local max=0
  local f

  shopt -s nullglob
  for f in "$session_folder"/"$project_name"-"$session_name"-part*.mp4; do
    local n
    n=$(basename "$f" | sed -E 's/.*-part([0-9]+)\.mp4/\1/')
    n=$((10#$n))
    if (( n > max )); then
      max=$n
    fi
  done
  shopt -u nullglob

  echo $((max + 1))
}

activate_context() {
  local project_name="$1"
  local session_name="$2"
  local naming="$3"

  CURRENT_PROJECT="$project_name"
  CURRENT_AI_SESSION="$session_name"
  PROJECT_FOLDER="$SESSION_BASE_DIR/$CURRENT_PROJECT"
  SESSION_FOLDER="$PROJECT_FOLDER/$CURRENT_AI_SESSION"
  OUTPUT_NAMING="$naming"

  mkdir -p "$PROJECT_FOLDER" "$SESSION_FOLDER"

  if [[ "$OUTPUT_NAMING" == "named" ]]; then
    CURRENT_PART="$(next_part_number "$SESSION_FOLDER" "$CURRENT_PROJECT" "$CURRENT_AI_SESSION")"
  else
    CURRENT_PART=0
  fi
}

resolve_context() {
  local explicit_project="${1:-}"
  local explicit_session="${2:-}"

  local resolved_project=""
  local resolved_session=""
  local resolved_naming=""

  if [[ -n "$explicit_project" ]]; then
    resolved_project="$explicit_project"
    resolved_naming="named"
  elif [[ -n "${AI_PROJECT:-}" ]]; then
    resolved_project="$AI_PROJECT"
    resolved_naming="named"
  elif [[ -n "$CURRENT_PROJECT" ]]; then
    resolved_project="$CURRENT_PROJECT"
    resolved_naming="$OUTPUT_NAMING"
  else
    resolved_project="$(default_project_name)"
    resolved_naming="flat"
  fi

  if [[ -n "$explicit_session" ]]; then
    resolved_session="$explicit_session"
  elif [[ -n "${AI_SESSION:-}" ]]; then
    resolved_session="$AI_SESSION"
  elif [[ -n "$CURRENT_AI_SESSION" ]]; then
    resolved_session="$CURRENT_AI_SESSION"
  else
    resolved_session="$(default_session_name)"
  fi

  activate_context "$resolved_project" "$resolved_session" "$resolved_naming"
}

prepare_project() {
  local project_name="${1:-}"
  local session_name="${2:-}"

  load_session_state

  if [[ -n "$project_name" ]]; then
    activate_context "$project_name" "${session_name:-$(default_session_name)}" "named"
  else
    activate_context "$(default_project_name)" "${session_name:-$(default_session_name)}" "flat"
  fi

  RECORDING_PID=""
  LAST_OUTPUT_FILE=""
  save_session_state

  echo "Project prepared: $CURRENT_PROJECT"
  echo "Session prepared: $CURRENT_AI_SESSION"
  echo "Project folder: $PROJECT_FOLDER"
  echo "Session folder: $SESSION_FOLDER"
  echo "Mode: $OUTPUT_NAMING"

  cd "$SESSION_FOLDER"
  populate_prompt_templates "$CURRENT_PROJECT" "$CURRENT_AI_SESSION"
  echo "Now in session folder: $SESSION_FOLDER"
  echo "Use: ai-session-manager.sh screencast start"
}

start_screencast() {
  local project_name="${1:-}"
  local session_name="${2:-}"
  local start_profile="region-audio"

  load_session_state
  resolve_context "$project_name" "$session_name"

  if recorder_is_running; then
    local active_pid=""
    if [[ -f "$RECORDER_PID_FILE" ]]; then
      active_pid="$(cat "$RECORDER_PID_FILE")"
    fi
    echo "Recording already active${active_pid:+ (PID $active_pid)}. Stop it first." >&2
    exit 1
  fi

  require_cmd wf-recorder

  # Recorder writes directly into the active session folder.
  WF_RECORD_OUTPUT_DIR="$SESSION_FOLDER" bash "$RECORDER_SCRIPT" region-audio >/dev/null
  sleep 1

  # Detect immediate recorder failure and auto-fallback to full output capture.
  if ! recorder_is_running; then
    cleanup_orphan_mic_capture
    echo "warning: region-audio failed to start; retrying with full-audio" >&2
    WF_RECORD_OUTPUT_DIR="$SESSION_FOLDER" bash "$RECORDER_SCRIPT" full-audio >/dev/null
    sleep 1
    start_profile="full-audio"
  fi

  if ! recorder_is_running; then
    cleanup_orphan_mic_capture
    echo "error: recording failed to start (region-audio and full-audio)" >&2
    echo "hint: check $RECORDER_RUNTIME_DIR/wf-record.log" >&2
    exit 1
  fi

  # Persist real recorder PID when available.
  if [[ -f "$RECORDER_PID_FILE" ]]; then
    RECORDING_PID="$(cat "$RECORDER_PID_FILE")"
  else
    RECORDING_PID=""
  fi

  LAST_OUTPUT_FILE=""
  save_session_state

  echo "Recording started (PID $RECORDING_PID)"
  echo "Project: $CURRENT_PROJECT"
  echo "Session: $CURRENT_AI_SESSION"
  echo "Mode: $OUTPUT_NAMING"
  if [[ "$OUTPUT_NAMING" == "named" ]]; then
    echo "Part: $CURRENT_PART"
  fi
  echo "Recorder profile: $start_profile"
  echo "Session folder: $SESSION_FOLDER"
}

stop_screencast() {
  local project_name="${1:-}"
  local session_name="${2:-}"

  load_session_state

  if [[ -n "$project_name" || -n "$session_name" ]]; then
    resolve_context "$project_name" "$session_name"
  fi

  [[ -n "$CURRENT_PROJECT" ]] || { echo "error: no active project" >&2; exit 1; }
  [[ -n "$CURRENT_AI_SESSION" ]] || { echo "error: no active session" >&2; exit 1; }
  if ! recorder_is_running; then
    echo "error: no active recording" >&2
    exit 1
  fi

  bash "$RECORDER_SCRIPT" stop
  sleep 1

  latest_mp4=$(find "$SESSION_FOLDER" -maxdepth 1 -name "screencast_*.mp4" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

  if [[ -n "$latest_mp4" && -f "$latest_mp4" ]]; then
    if [[ "$OUTPUT_NAMING" == "named" ]]; then
      part_file="$SESSION_FOLDER/${CURRENT_PROJECT}-${CURRENT_AI_SESSION}-part$(printf '%02d' "$CURRENT_PART").mp4"
      while [[ -f "$part_file" ]]; do
        CURRENT_PART=$((CURRENT_PART + 1))
        part_file="$SESSION_FOLDER/${CURRENT_PROJECT}-${CURRENT_AI_SESSION}-part$(printf '%02d' "$CURRENT_PART").mp4"
      done
      mv "$latest_mp4" "$part_file"
      LAST_OUTPUT_FILE="$part_file"
      echo "Recorded: $part_file"
      CURRENT_PART=$((CURRENT_PART + 1))
    else
      LAST_OUTPUT_FILE="$latest_mp4"
      echo "Recorded: $latest_mp4"
    fi
  else
    echo "warning: no new recording found in $SESSION_FOLDER" >&2
  fi

  RECORDING_PID=""
  save_session_state
}

next_screencast() {
  local project_name="${1:-}"
  local session_name="${2:-}"

  stop_screencast "$project_name" "$session_name"
  start_screencast "$project_name" "$session_name"
}

status_session() {
  local project_name="${1:-}"
  local session_name="${2:-}"

  load_session_state

  if [[ -n "$project_name" || -n "$session_name" ]]; then
    resolve_context "$project_name" "$session_name"
  elif [[ -z "$CURRENT_PROJECT" || -z "$CURRENT_AI_SESSION" ]]; then
    resolve_context "" ""
  fi

  echo "Active project: $CURRENT_PROJECT"
  echo "Active session: $CURRENT_AI_SESSION"
  echo "Project folder: $PROJECT_FOLDER"
  echo "Session folder: $SESSION_FOLDER"
  echo "Mode: $OUTPUT_NAMING"
  if [[ "$OUTPUT_NAMING" == "named" ]]; then
    echo "Next part: $(printf '%02d' "$CURRENT_PART")"
  fi

  if recorder_is_running; then
    if [[ -f "$RECORDER_PID_FILE" ]]; then
      RECORDING_PID="$(cat "$RECORDER_PID_FILE")"
    fi
    echo "Recording: active${RECORDING_PID:+ (PID $RECORDING_PID)}"
  else
    RECORDING_PID=""
    echo "Recording: stopped"
  fi

  echo "Last output: ${LAST_OUTPUT_FILE:-none}"
  echo
  echo "Files in session folder:"
  ls -lh "$SESSION_FOLDER" || true

  save_session_state
}

project_activate() {
  local project_name="${1:-}"
  local session_name="${2:-}"

  [[ -n "$project_name" ]] || { echo "error: project name required" >&2; exit 1; }

  load_session_state
  activate_context "$project_name" "${session_name:-$(default_session_name)}" "named"
  RECORDING_PID=""
  LAST_OUTPUT_FILE=""
  save_session_state

  echo "Project context activated: $CURRENT_PROJECT"
  echo "Session context activated: $CURRENT_AI_SESSION"
  echo "Session folder: $SESSION_FOLDER"
  echo "Tip: export AI_PROJECT=$CURRENT_PROJECT"
  echo "Tip: export AI_SESSION=$CURRENT_AI_SESSION"
}

session_activate() {
  local session_name="${1:-}"

  load_session_state
  resolve_context "" "${session_name:-$(default_session_name)}"
  RECORDING_PID=""
  LAST_OUTPUT_FILE=""
  save_session_state

  echo "Session context activated: $CURRENT_AI_SESSION"
  echo "Session folder: $SESSION_FOLDER"
  echo "Project: $CURRENT_PROJECT"
}

project_clear() {
  clear_session_state
  echo "Project/session context cleared"
}

# ---------------------------------------------------------------------------
# create_minutes / update_minutes
# Both commands are identical – update-minutes is a robust idempotent re-run.
# ---------------------------------------------------------------------------

create_minutes() {
  local mode="${1:-create-minutes}"
  shift || true

  local gemini_max_bytes=$((100 * 1024 * 1024))
  local gemini_max_seconds=$((3 * 60 * 60))

  # ---- parse options -------------------------------------------------------
  local opt_title=""
  local opt_owner=""
  local opt_date=""
  local opt_asr="false"
  local opt_overwrite="false"
  local opt_force_minutes="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)        opt_title="${2:-}";    shift 2 ;;
      --owner)        opt_owner="${2:-}";    shift 2 ;;
      --date)         opt_date="${2:-}";     shift 2 ;;
      --asr)          opt_asr="true";        shift   ;;
      --overwrite)    opt_overwrite="true";  shift   ;;
      --force-minutes) opt_force_minutes="true"; shift ;;
      -h|--help)
        echo "Usage: ai-session-manager.sh create-minutes [--title <t>] [--owner <n>]"
        echo "       [--date <YYYY-MM-DD>] [--asr] [--overwrite] [--force-minutes]"
        return 0 ;;
      *) echo "error: unknown option: $1" >&2; return 1 ;;
    esac
  done

  # ---- resolve active session context -------------------------------------
  load_session_state
  [[ -n "$CURRENT_PROJECT" ]]    || { echo "error: no active project (run prepare first)" >&2; return 1; }
  [[ -n "$CURRENT_AI_SESSION" ]] || { echo "error: no active session (run prepare first)" >&2; return 1; }

  local session_dir="$SESSION_FOLDER"
  local session_id="${CURRENT_PROJECT}-${CURRENT_AI_SESSION}"
  local meeting_date="${opt_date:-$(date +%Y-%m-%d)}"
  local title="${opt_title:-${CURRENT_PROJECT} ${CURRENT_AI_SESSION}}"
  local owner="${opt_owner:-TBD}"

  transcript_marker_path() {
    local transcript_file="$1"
    local transcript_dir base marker_name
    transcript_dir="$(dirname "$transcript_file")"
    base="$(basename "$transcript_file")"
    if [[ "$base" =~ -part([0-9]+)\.txt$ ]]; then
      marker_name=".part${BASH_REMATCH[1]}"
    else
      marker_name=".${base%.txt}"
    fi
    printf '%s/%s' "$transcript_dir" "$marker_name"
  }

  transcript_is_legacy_placeholder() {
    local transcript_file="$1"
    [[ -s "$transcript_file" ]] || return 1
    grep -q '^TODO: raw text transcript' "$transcript_file" 2>/dev/null
  }

  sync_transcript_marker() {
    local transcript_file="$1"
    local marker_file
    marker_file="$(transcript_marker_path "$transcript_file")"

    if [[ -s "$transcript_file" ]]; then
      : > "$marker_file"
      return 0
    fi
  }

  ensure_transcript_placeholder() {
    local wav_file="$1"
    local transcript_file="${wav_file%.wav}.txt"
    local marker_file
    marker_file="$(transcript_marker_path "$transcript_file")"

    if [[ ! -e "$transcript_file" ]]; then
      : > "$transcript_file"
      echo "      Placeholder: $(basename "$transcript_file")"
    else
      echo "      Empty transcript placeholder: $(basename "$transcript_file")"
    fi

    : > "$marker_file"
  }

  transcript_is_real() {
    local transcript_file="$1"
    [[ -s "$transcript_file" ]] && ! transcript_is_legacy_placeholder "$transcript_file"
  }

  is_master_part_wav() {
    local wav_file="$1"
    [[ "$wav_file" =~ -part[0-9]+\.wav$ ]]
  }

  split_part_wav_for_gemini() {
    local wav_file="$1"
    local overwrite_mode="$2"
    local session_folder="$3"
    local base_name
    local chunk_pattern
    local split_dir
    local split_gitignore
    local size_bytes
    local sample_rate
    local channels
    local bits_per_sample
    local bytes_per_second
    local max_seconds_by_size
    local segment_seconds
    local tmp_dir
    local generated=0
    local idx=1

    base_name="$(basename "${wav_file%.wav}")"
    split_dir="$session_folder/.audio-split"
    split_gitignore="$split_dir/.gitignore"
    chunk_pattern="$split_dir/${base_name}-index*.wav"

    mkdir -p "$split_dir"
    if [[ ! -f "$split_gitignore" ]]; then
      cat > "$split_gitignore" <<'EOF'
*
!.gitignore
EOF
    fi

    if [[ "$overwrite_mode" != "true" ]]; then
      shopt -s nullglob
      local existing_chunks=("$split_dir"/${base_name}-index*.wav)
      shopt -u nullglob
      if [[ ${#existing_chunks[@]} -gt 0 ]]; then
        for c in "${existing_chunks[@]}"; do
          echo "$c"
        done
        return 0
      fi
    else
      rm -f "$split_dir"/${base_name}-index*.wav
    fi

    size_bytes=$(stat -c '%s' "$wav_file" 2>/dev/null || echo 0)
    sample_rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$wav_file" 2>/dev/null | head -1)
    channels=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "$wav_file" 2>/dev/null | head -1)
    bits_per_sample=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_sample -of csv=p=0 "$wav_file" 2>/dev/null | head -1)

    if [[ -z "$sample_rate" || -z "$channels" || -z "$bits_per_sample" ]]; then
      echo "$wav_file"
      return 0
    fi

    bytes_per_second=$((sample_rate * channels * bits_per_sample / 8))
    if (( bytes_per_second <= 0 )); then
      echo "$wav_file"
      return 0
    fi

    max_seconds_by_size=$((gemini_max_bytes / bytes_per_second))
    segment_seconds=$gemini_max_seconds
    if (( max_seconds_by_size > 0 && max_seconds_by_size < segment_seconds )); then
      segment_seconds=$max_seconds_by_size
    fi

    if (( segment_seconds <= 0 )); then
      echo "$wav_file"
      return 0
    fi

    if (( size_bytes <= gemini_max_bytes && segment_seconds >= gemini_max_seconds )); then
      echo "$wav_file"
      return 0
    fi

    tmp_dir=$(mktemp -d)
    ffmpeg -hide_banner -loglevel error -y \
      -i "$wav_file" \
      -f segment -segment_time "$segment_seconds" -reset_timestamps 1 -c copy \
      "$tmp_dir/chunk_%03d.wav"

    shopt -s nullglob
    local raw_chunks=("$tmp_dir"/chunk_*.wav)
    shopt -u nullglob

    if [[ ${#raw_chunks[@]} -eq 0 ]]; then
      rm -rf "$tmp_dir"
      echo "$wav_file"
      return 0
    fi

    for raw_chunk in "${raw_chunks[@]}"; do
      local out_chunk
      out_chunk=$(printf '%s/%s-index%02d.wav' "$split_dir" "$base_name" "$idx")
      mv "$raw_chunk" "$out_chunk"
      echo "$out_chunk"
      idx=$((idx + 1))
      generated=$((generated + 1))
    done

    rm -rf "$tmp_dir"

    if (( generated > 1 )); then
      echo "" >&2
      echo "      Partitioned $(basename "$wav_file") into $generated chunk(s) for Gemini limits." >&2
    fi
  }

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local extract_script="$script_dir/extract-session-audio.sh"
  local merge_script="$script_dir/merge-session-transcripts.sh"
  local skeleton_script="$script_dir/create-meeting-minutes-skeleton.sh"

  for s in "$extract_script" "$merge_script" "$skeleton_script"; do
    [[ -x "$s" ]] || { echo "error: helper not executable: $s" >&2; return 1; }
  done

  echo "=== create-minutes ==================================================="
  echo "Project  : $CURRENT_PROJECT"
  echo "Session  : $CURRENT_AI_SESSION"
  echo "Folder   : $session_dir"
  echo "Session ID: $session_id"
  echo "Date     : $meeting_date"
  echo "ASR mode : $opt_asr"
  echo "Run mode  : $mode"
  echo "======================================================================"

  # ---- Step 1: collect video parts -----------------------------------------
  shopt -s nullglob
  local mp4_files=("$session_dir"/*part*.mp4)
  shopt -u nullglob

  if [[ ${#mp4_files[@]} -eq 0 ]]; then
    echo "warning: no *part*.mp4 files found in $session_dir"
    echo "         Continuing – audio/transcript/minutes steps may produce empty results."
  else
    echo
    echo "[1/4] Video parts (${#mp4_files[@]} found):"
    for f in "${mp4_files[@]}"; do
      echo "      $(basename "$f")  ($(du -sh "$f" | cut -f1))"
    done
  fi

  # ---- Step 2: extract audio -----------------------------------------------
  echo
  echo "[2/4] Audio extraction"
  if [[ ${#mp4_files[@]} -gt 0 ]]; then
    require_cmd ffmpeg
    local extract_args=("$session_dir" --format wav --sample-rate 16000 --channels 1 --pattern '*part*.mp4')
    [[ "$opt_overwrite" == "true" ]] && extract_args+=(--overwrite)
    bash "$extract_script" "${extract_args[@]}"
  else
    echo "      Skipped – no mp4 parts."
  fi

  # ---- Step 3: transcripts --------------------------------------------------
  echo
  echo "[3/4] Transcripts"

  shopt -s nullglob
  local wav_candidates=("$session_dir"/*part*.wav)
  shopt -u nullglob

  local wav_files=()
  local effective_wav_files=()
  if [[ ${#wav_candidates[@]} -gt 0 ]]; then
    require_cmd ffprobe
    for wav in "${wav_candidates[@]}"; do
      if is_master_part_wav "$wav"; then
        wav_files+=("$wav")
      fi
    done

    if [[ ${#wav_files[@]} -gt 0 ]]; then
      for wav in "${wav_files[@]}"; do
        while IFS= read -r chunk_file; do
          [[ -n "$chunk_file" ]] && effective_wav_files+=("$chunk_file")
        done < <(split_part_wav_for_gemini "$wav" "$opt_overwrite" "$session_dir")
      done
    fi

    if [[ ${#effective_wav_files[@]} -gt 0 ]]; then
      IFS=$'\n' effective_wav_files=($(printf '%s\n' "${effective_wav_files[@]}" | sort -u))
      unset IFS
      wav_files=("${effective_wav_files[@]}")
    fi
  fi

  if [[ ${#wav_files[@]} -eq 0 ]]; then
    echo "      No wav files found – skipping transcript step."
  elif [[ "$opt_asr" == "true" ]]; then
    # --- ASR path (whisper-cli) ---------------------------------------------
    local model="$HOME/models/ggml-large-v3.bin"
    if ! command -v whisper-cli >/dev/null 2>&1; then
      echo "      TODO: whisper-cli is not installed."
      echo "      Install steps (see dotfiles runbook for full details):"
      echo "        1. Install NVIDIA driver: sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
      echo "        2. Build whisper.cpp with CUDA: cd ~/tools/whisper.cpp && make GGML_CUDA=1"
      echo "        3. Install: sudo cp build/bin/whisper-cli /usr/local/bin/whisper-cli"
      echo "        4. Download model: bash models/download-ggml-model.sh large-v3"
      echo "        5. mkdir -p ~/models && cp models/ggml-large-v3.bin ~/models/"
      echo "      Falling back to manual-placeholder mode for now."
      opt_asr="false"
    elif [[ ! -f "$model" ]]; then
      echo "      TODO: model not found at $model"
      echo "      Run: bash ~/tools/whisper.cpp/models/download-ggml-model.sh large-v3"
      echo "      Then: mkdir -p ~/models && cp ~/tools/whisper.cpp/models/ggml-large-v3.bin ~/models/"
      echo "      Falling back to manual-placeholder mode for now."
      opt_asr="false"
    fi

    if [[ "$opt_asr" == "true" ]]; then
      for wav in "${wav_files[@]}"; do
        local txt="${wav%.wav}.txt"
        if transcript_is_legacy_placeholder "$txt"; then
          : > "$txt"
          echo "      Reset legacy placeholder: $(basename "$txt")"
        fi
        if transcript_is_real "$txt" && [[ "$opt_overwrite" != "true" ]]; then
          echo "      Skip existing: $(basename "$txt")"
          continue
        fi
        echo "      Transcribing: $(basename "$wav")"
        whisper-cli -m "$model" -f "$wav" -of "${wav%.wav}" -l auto
        echo "      Created: $(basename "$txt")"
      done
    fi

    for wav in "${wav_files[@]}"; do
      sync_transcript_marker "${wav%.wav}.txt"
    done
  fi

  # manual-placeholder mode (also the fallback when ASR is requested but unavailable)
  if [[ "$opt_asr" == "false" ]]; then
    local placeholder_count=0
    for wav in "${wav_files[@]}"; do
      local txt="${wav%.wav}.txt"
      if transcript_is_legacy_placeholder "$txt"; then
        : > "$txt"
        echo "      Reset legacy placeholder: $(basename "$txt")"
      fi
      if transcript_is_real "$txt"; then
        echo "      Keep existing transcript: $(basename "$txt")"
        continue
      fi

      if [[ ! -e "$txt" || "$opt_overwrite" == "true" ]]; then
        : > "$txt"
        placeholder_count=$((placeholder_count + 1))
        echo "      Placeholder: $(basename "$txt")"
      else
        echo "      Empty transcript placeholder: $(basename "$txt")"
      fi

      ensure_transcript_placeholder "$wav"
    done
    if [[ $placeholder_count -gt 0 ]]; then
      echo
      echo "      $placeholder_count placeholder(s) created."
      echo "      Fill them with real transcripts, then rerun: ai-session-manager.sh update-minutes"
    fi

    for wav in "${wav_files[@]}"; do
      sync_transcript_marker "${wav%.wav}.txt"
    done
  fi

  # ---- Step 4: merge + skeleton --------------------------------------------
  echo
  echo "[4/4] Transcript merge and minutes skeleton"

  local txt_files=()
  local transcript_dirs=("$session_dir")
  if [[ -d "$session_dir/.audio-split" ]]; then
    transcript_dirs+=("$session_dir/.audio-split")
  fi

  for d in "${transcript_dirs[@]}"; do
    shopt -s nullglob
    local part_txt=($d/*part*.txt)
    shopt -u nullglob
    if [[ ${#part_txt[@]} -gt 0 ]]; then
      txt_files+=("${part_txt[@]}")
    fi
  done

  if [[ ${#txt_files[@]} -gt 0 ]]; then
    IFS=$'\n' txt_files=($(printf '%s\n' "${txt_files[@]}" | sort -uV))
    unset IFS
  fi

  # Only merge when at least one transcript file has actual content.
  local real_transcripts=0
  for t in "${txt_files[@]}"; do
    if transcript_is_real "$t"; then
      real_transcripts=$((real_transcripts + 1))
    fi
  done

  local merged_transcript="$session_dir/$session_id-merged-transcript.txt"
  local merge_overwrite="$opt_overwrite"
  local force_minutes="$opt_force_minutes"

  if [[ "$mode" == "update-minutes" ]]; then
    merge_overwrite="true"
    force_minutes="true"
  fi

  if [[ ${#txt_files[@]} -eq 0 ]]; then
    echo "      No transcript files found – skipping merge."
  elif [[ $real_transcripts -eq 0 ]]; then
    : > "$merged_transcript"
    echo "      All transcript files are empty placeholders – created empty merged transcript."
    echo "      Fill transcripts, then rerun: ai-session-manager.sh update-minutes"
  else
    echo "      Merging $real_transcripts real transcript(s) of ${#txt_files[@]} total."
    : > "$merged_transcript"
    for t in "${txt_files[@]}"; do
      {
        echo
        echo "---"
        echo "SourcePart: $(basename "$t")"
        echo
      } >> "$merged_transcript"
      cat "$t" >> "$merged_transcript"
      echo >> "$merged_transcript"
    done
    echo "Merged ${#txt_files[@]} parts into: $merged_transcript"
  fi

  # Minutes skeleton: always create/update so the source inventory is current.
  local minutes_output="$session_dir/$session_id-meeting-minutes.md"
  local skeleton_args=("$session_dir" "$session_id"
    --title "$title"
    --owner "$owner"
    --date "$meeting_date"
    --output "$minutes_output"
  )
  [[ -f "$merged_transcript" ]] && skeleton_args+=(--transcript "$merged_transcript")
  [[ "$force_minutes" == "true" ]] && skeleton_args+=(--force)

  if [[ -f "$minutes_output" && "$force_minutes" != "true" ]]; then
    echo "      Minutes skeleton already exists: $(basename "$minutes_output")"
    echo "      Use --force-minutes to overwrite."
  else
    bash "$skeleton_script" "${skeleton_args[@]}"
  fi

  echo
  echo "=== Summary ==========================================================="
  echo "Session folder: $session_dir"
  if [[ -d "$session_dir/.audio-split" ]]; then
    echo "Split folder  : $session_dir/.audio-split"
  fi
  echo
  echo "Artifacts:"
  ls -lh "$session_dir" | awk 'NR>1 {print "  " $0}'
  echo
  if [[ $real_transcripts -gt 0 && -f "$merged_transcript" ]]; then
    echo "Next: open ~/dotfiles/ai/teams-session-meeting-minutes-prompt.md"
    echo "      Fill the placeholders and submit to your AI assistant."
    echo "      Save the output into: $(basename "$minutes_output")"
  else
    echo "Next: fill transcript placeholder .txt files in $session_dir and (if present) $session_dir/.audio-split"
    echo "      Then rerun: ai-session-manager.sh update-minutes"
  fi
  echo "======================================================================="
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

command_name="${1:-}"

case "$command_name" in
  prepare)
    prepare_project "${2:-}" "${3:-}"
    ;;
  screencast)
    [[ $# -ge 2 ]] || { echo "error: screencast subcommand required" >&2; usage; exit 1; }
    case "${2:-}" in
      start)
        start_screencast "${3:-}" "${4:-}"
        ;;
      stop)
        stop_screencast "${3:-}" "${4:-}"
        ;;
      next)
        next_screencast "${3:-}" "${4:-}"
        ;;
      *)
        echo "error: unknown screencast subcommand: $2" >&2
        usage
        exit 1
        ;;
    esac
    ;;
  status)
    status_session "${2:-}" "${3:-}"
    ;;
  project)
    [[ $# -ge 2 ]] || { echo "error: project subcommand required" >&2; usage; exit 1; }
    case "${2:-}" in
      activate)
        [[ $# -ge 3 ]] || { echo "error: project name required" >&2; usage; exit 1; }
        project_activate "${3:-}" "${4:-}"
        ;;
      clear)
        project_clear
        ;;
      *)
        echo "error: unknown project subcommand: $2" >&2
        usage
        exit 1
        ;;
    esac
    ;;
  session)
    [[ $# -ge 2 ]] || { echo "error: session subcommand required" >&2; usage; exit 1; }
    case "${2:-}" in
      activate)
        session_activate "${3:-}"
        ;;
      *)
        echo "error: unknown session subcommand: $2" >&2
        usage
        exit 1
        ;;
    esac
    ;;
  list)
    shift
    if [[ $# -gt 0 ]]; then
      list_projects "$1"
    else
      list_projects
    fi
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  create-minutes|update-minutes)
    shift
    create_minutes "$command_name" "$@"
    ;;
  paths)
    print_paths
    ;;
  doctor)
    doctor
    ;;
  *)
    echo "error: unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
