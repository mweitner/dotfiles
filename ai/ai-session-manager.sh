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
  project activate <name> [session]
                                  Activate project context (session optional)
  project clear                    Clear persisted context
  session activate [name]          Activate session within active project

Environment:
  AI_SESSION_DIR                  Override project base directory (default: ~/.ai-sessions)
  AI_SESSION_CONFIG               Override config file location
  AI_PROJECT                      Shell-level active project context override
  AI_SESSION                      Shell-level active session context override

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
CONFIG_DIR="${XDG_RUNTIME_DIR:-/tmp}/ai-session"
CONFIG_FILE="${AI_SESSION_CONFIG:-$CONFIG_DIR/session.state}"
RECORDER_SCRIPT="$HOME/.config/sway/scripts/wf-record.sh"
RECORDER_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
RECORDER_PID_FILE="$RECORDER_RUNTIME_DIR/wf-record.pid"

mkdir -p "$CONFIG_DIR"

default_project_name() {
  date +%Y.%m
}

default_session_name() {
  date +%Y.%m.%d
}

load_session_state() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  fi

  # Backward compatibility with legacy variable names.
  if [[ -z "${CURRENT_PROJECT:-}" && -n "${CURRENT_SESSION:-}" ]]; then
    CURRENT_PROJECT="$CURRENT_SESSION"
  fi

  # Legacy SESSION_FOLDER used to point to project folder.
  if [[ -z "${PROJECT_FOLDER:-}" && -n "${SESSION_FOLDER:-}" ]]; then
    PROJECT_FOLDER="$SESSION_FOLDER"
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
  cat > "$CONFIG_FILE" <<EOF
CURRENT_PROJECT="$CURRENT_PROJECT"
CURRENT_AI_SESSION="$CURRENT_AI_SESSION"
PROJECT_FOLDER="$PROJECT_FOLDER"
SESSION_FOLDER="$SESSION_FOLDER"
OUTPUT_NAMING="$OUTPUT_NAMING"
CURRENT_PART="$CURRENT_PART"
RECORDING_PID="${RECORDING_PID:-}"
LAST_OUTPUT_FILE="${LAST_OUTPUT_FILE:-}"

# Legacy aliases for compatibility
CURRENT_SESSION="$CURRENT_PROJECT"
EOF
}

clear_session_state() {
  rm -f "$CONFIG_FILE"
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
  echo "Now in session folder: $SESSION_FOLDER"
  echo "Use: ai-session-manager.sh screencast start"
}

start_screencast() {
  local project_name="${1:-}"
  local session_name="${2:-}"

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

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

case "${1:-}" in
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
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "error: unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
