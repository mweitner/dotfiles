#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-meeting-minutes-skeleton.sh <repo-root> <session-id> [options]

Create a markdown skeleton for one Teams meeting minutes document.

Options:
  --title <text>           Custom meeting title
  --owner <name>           Default owner for unresolved action items
  --date <YYYY-MM-DD>      Meeting date (default: today)
  --transcript <path>      Transcript source path hint
  --chat-md <path>         Teams chat markdown source path hint
  --output <path>          Output file path
  --force                  Replace output file if it exists
  -h, --help               Show help

Example:
  create-meeting-minutes-skeleton.sh ~/dps-dev teams-2026-08-13-lpo \
    --title "LPO Edge Interface Session" \
    --transcript "$HOME/videos/screencasts/teams-2026-08-13-lpo/teams-2026-08-13-lpo-merged-transcript.txt" \
    --chat-md ~/dps-dev/docs/ai-context/teams-sync-2026-08-13-teams-2026-08-13-lpo.md
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

repo_root="$1"
session_id="$2"
shift 2

title=""
owner=""
meeting_date="$(date +%Y-%m-%d)"
transcript_path=""
chat_md_path=""
output=""
force="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      title="${2:-}"
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
    --transcript)
      transcript_path="${2:-}"
      shift 2
      ;;
    --chat-md)
      chat_md_path="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --force)
      force="true"
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

[[ -d "$repo_root" ]] || { echo "Repo root not found: $repo_root" >&2; exit 1; }

if [[ -z "$title" ]]; then
  title="Teams Meeting Minutes - $session_id"
fi

if [[ -z "$output" ]]; then
  output="$repo_root/docs/ai-context/teams-mm-$session_id.md"
fi

if [[ -f "$output" && "$force" != "true" ]]; then
  echo "Output exists: $output (use --force to replace)" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"

cat > "$output" <<EOF
# $title

SessionId: $session_id
Date: $meeting_date
Status: draft

## Session Metadata

- Meeting date: $meeting_date
- Facilitator:
- Participants:
- Recording parts:

## Decisions

- Decision 1:
- Decision 2:

## Requirement / Architecture Impact

- Requirement delta:
- Architecture impact:
- Implementation impact:

## Action Items

| Action | Owner | Due Date | Status |
|---|---|---|---|
| | ${owner:-TBD} | | open |

## Open Questions

- Question 1:
- Question 2:

## Risks and Assumptions

- Risk:
- Assumption:

## Sources

- Transcript: ${transcript_path:-TBD}
- Teams chat markdown: ${chat_md_path:-TBD}
- Related requirements:

EOF

echo "Created: $output"
