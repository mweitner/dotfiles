#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-session-postprocess.sh <session-dir> <session-id> <repo-root> [options]

Run session post-processing in one command:
1) extract audio from mp4 parts
2) merge transcript parts
3) create meeting minutes skeleton markdown

Options:
  --audio-format <wav|mp3>      Output audio format (default: wav)
  --sample-rate <hz>            Audio sample rate (default: 16000)
  --channels <count>            Audio channels (default: 1)
  --video-pattern <glob>        Video file pattern (default: *part*.mp4)
  --transcript-pattern <glob>   Transcript pattern for merge (default: *part*.txt)
  --minutes-title <text>        Custom meeting minutes title
  --owner <name>                Default owner in meeting minutes skeleton
  --date <YYYY-MM-DD>           Meeting date (default: today)
  --chat-md <path>              Teams chat markdown source path hint
  --minutes-output <path>       Output file path for meeting minutes skeleton
  --skip-extract                Skip audio extraction step
  --skip-merge                  Skip transcript merge step
  --skip-skeleton               Skip meeting skeleton generation step
  --overwrite-audio             Overwrite extracted audio files
  --overwrite-merge             Overwrite merged transcript file
  --force-minutes               Overwrite meeting minutes skeleton file
  -h, --help                    Show help

Example:
  run-session-postprocess.sh "$HOME/videos/screencasts/teams-2026-08-13-lpo" \
    teams-2026-08-13-lpo ~/dps-dev \
    --chat-md ~/dps-dev/docs/ai-context/teams-sync-2026-08-13-teams-2026-08-13-lpo.md \
    --owner "Michael Weitner"
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

session_dir="$1"
session_id="$2"
repo_root="$3"
shift 3

audio_format="wav"
sample_rate="16000"
channels="1"
video_pattern="*part*.mp4"
transcript_pattern="*part*.txt"
minutes_title=""
owner=""
meeting_date="$(date +%Y-%m-%d)"
chat_md=""
minutes_output=""

skip_extract="false"
skip_merge="false"
skip_skeleton="false"

overwrite_audio="false"
overwrite_merge="false"
force_minutes="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audio-format)
      audio_format="${2:-}"
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
    --video-pattern)
      video_pattern="${2:-}"
      shift 2
      ;;
    --transcript-pattern)
      transcript_pattern="${2:-}"
      shift 2
      ;;
    --minutes-title)
      minutes_title="${2:-}"
      shift 2
      ;;
    --owner)
      owner="${2:-}"
      shift 2
      ;;
    --date)
      meeting_date="${2:-}"
      shift 2
      ;;
    --chat-md)
      chat_md="${2:-}"
      shift 2
      ;;
    --minutes-output)
      minutes_output="${2:-}"
      shift 2
      ;;
    --skip-extract)
      skip_extract="true"
      shift
      ;;
    --skip-merge)
      skip_merge="true"
      shift
      ;;
    --skip-skeleton)
      skip_skeleton="true"
      shift
      ;;
    --overwrite-audio)
      overwrite_audio="true"
      shift
      ;;
    --overwrite-merge)
      overwrite_merge="true"
      shift
      ;;
    --force-minutes)
      force_minutes="true"
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
[[ -d "$repo_root" ]] || { echo "Repo root not found: $repo_root" >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extract_script="$script_dir/extract-session-audio.sh"
merge_script="$script_dir/merge-session-transcripts.sh"
skeleton_script="$script_dir/create-meeting-minutes-skeleton.sh"

[[ -x "$extract_script" ]] || { echo "Helper not executable: $extract_script" >&2; exit 1; }
[[ -x "$merge_script" ]] || { echo "Helper not executable: $merge_script" >&2; exit 1; }
[[ -x "$skeleton_script" ]] || { echo "Helper not executable: $skeleton_script" >&2; exit 1; }

if [[ "$skip_extract" != "true" ]]; then
  require_cmd ffmpeg
  echo "[1/3] Extract audio"
  extract_args=(
    "$session_dir"
    --format "$audio_format"
    --sample-rate "$sample_rate"
    --channels "$channels"
    --pattern "$video_pattern"
  )
  if [[ "$overwrite_audio" == "true" ]]; then
    extract_args+=(--overwrite)
  fi
  bash "$extract_script" "${extract_args[@]}"
else
  echo "[1/3] Skip audio extraction"
fi

merged_transcript="$session_dir/$session_id-merged-transcript.txt"

if [[ "$skip_merge" != "true" ]]; then
  echo "[2/3] Merge transcripts"
  merge_args=(
    "$session_dir"
    "$session_id"
    --pattern "$transcript_pattern"
  )
  if [[ "$overwrite_merge" == "true" ]]; then
    merge_args+=(--overwrite)
  fi
  bash "$merge_script" "${merge_args[@]}"
else
  echo "[2/3] Skip transcript merge"
fi

if [[ "$skip_skeleton" != "true" ]]; then
  echo "[3/3] Create meeting minutes skeleton"
  skeleton_args=(
    "$repo_root"
    "$session_id"
    --date "$meeting_date"
    --transcript "$merged_transcript"
  )
  [[ -n "$minutes_title" ]] && skeleton_args+=(--title "$minutes_title")
  [[ -n "$owner" ]] && skeleton_args+=(--owner "$owner")
  [[ -n "$chat_md" ]] && skeleton_args+=(--chat-md "$chat_md")
  [[ -n "$minutes_output" ]] && skeleton_args+=(--output "$minutes_output")
  [[ "$force_minutes" == "true" ]] && skeleton_args+=(--force)
  bash "$skeleton_script" "${skeleton_args[@]}"
else
  echo "[3/3] Skip meeting skeleton generation"
fi

echo
echo "Session post-processing complete."
echo "Next: run ASR transcription before merge if transcript parts are not generated yet."
