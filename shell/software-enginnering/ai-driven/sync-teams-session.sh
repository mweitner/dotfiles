#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_SCRIPT="$SCRIPT_DIR/fetch-teams-json.py"
PARSE_SCRIPT="$SCRIPT_DIR/parse-teams-json.py"

CONTEXT_CATEGORY="supplier-pilots"
PARTNER_NAME="external-partner"
DESCRIPTION="Teams conversation context artifact"
GRAPH_TOKEN="${MS_GRAPH_TOKEN:-}"
GRAPH_TOKEN_FILE=""
INCLUDE_REPLIES=0
INPUT_SOURCE=""
INPUT_MODE="file"

print_help() {
  cat <<'EOF'
Usage:
  sync-teams-session.sh <teams_json_or_url> [context_category] [partner_name] [OPTIONS]

Options:
  --description <text>
  --graph-token <token>
  --graph-token-file <path>
  --include-replies
  --output <path>
  -h, --help

Output default:
  ./source/_static/communication/teams/<category>/<partner>/<YYYY-MM-DD>_teams_context.md
EOF
}

require_option_value() {
  local opt_name="$1"
  local opt_value="${2:-}"
  if [[ -z "$opt_value" || "$opt_value" == --* ]]; then
    echo "Error: option $opt_name requires a value" >&2
    exit 1
  fi
}

OUTPUT_MD=""

parse_args() {
  if [[ $# -eq 0 ]]; then
    print_help
    exit 1
  fi

  if [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
    print_help
    exit 0
  fi

  INPUT_SOURCE="$1"
  shift

  if [[ $# -gt 0 && "$1" != --* ]]; then
    CONTEXT_CATEGORY="$1"
    shift
  fi

  if [[ $# -gt 0 && "$1" != --* ]]; then
    PARTNER_NAME="$1"
    shift
  fi

  if [[ "$INPUT_SOURCE" =~ ^https://teams\.microsoft\.com/ ]]; then
    INPUT_MODE="url"
  else
    if [[ ! -f "$INPUT_SOURCE" ]]; then
      echo "Error: input file not found: $INPUT_SOURCE" >&2
      exit 1
    fi
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --description)
        require_option_value "--description" "${2:-}"
        DESCRIPTION="$2"
        shift 2
        ;;
      --graph-token)
        require_option_value "--graph-token" "${2:-}"
        GRAPH_TOKEN="$2"
        shift 2
        ;;
      --graph-token-file)
        require_option_value "--graph-token-file" "${2:-}"
        GRAPH_TOKEN_FILE="$2"
        shift 2
        ;;
      --include-replies)
        INCLUDE_REPLIES=1
        shift
        ;;
      --output)
        require_option_value "--output" "${2:-}"
        OUTPUT_MD="$2"
        shift 2
        ;;
      -h|--help)
        print_help
        exit 0
        ;;
      *)
        echo "Error: unknown option: $1" >&2
        print_help
        exit 1
        ;;
    esac
  done

  if [[ -n "$GRAPH_TOKEN_FILE" ]]; then
    if [[ ! -f "$GRAPH_TOKEN_FILE" ]]; then
      echo "Error: graph token file not found: $GRAPH_TOKEN_FILE" >&2
      exit 1
    fi
    GRAPH_TOKEN="$(head -n 1 "$GRAPH_TOKEN_FILE" | tr -d '\r\n')"
  fi
}

ensure_dependencies() {
  command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found" >&2; exit 1; }
  python3 -c "import bs4" >/dev/null 2>&1 || python3 -m pip install beautifulsoup4 --quiet
  [[ -f "$FETCH_SCRIPT" ]] || { echo "Error: fetch script missing: $FETCH_SCRIPT" >&2; exit 1; }
  [[ -f "$PARSE_SCRIPT" ]] || { echo "Error: parse script missing: $PARSE_SCRIPT" >&2; exit 1; }
}

build_default_output() {
  local root="${PWD}"
  local date_str
  date_str="$(date -u '+%Y-%m-%d')"
  echo "$root/source/_static/communication/teams/$CONTEXT_CATEGORY/$PARTNER_NAME/${date_str}_teams_context.md"
}

generate_artifact() {
  local parsed_md="$1"
  local final_md="$2"

  mkdir -p "$(dirname "$final_md")"
  {
    echo "---"
    echo "title: Teams Context"
    echo "category: $CONTEXT_CATEGORY"
    echo "partner: $PARTNER_NAME"
    echo "date: $(date -u '+%Y-%m-%d')"
    echo "description: $DESCRIPTION"
    echo "---"
    echo
    echo "# Teams Context: $PARTNER_NAME"
    echo
    echo "**Date:** $(date -u '+%Y-%m-%d %H:%M %p')"
    echo
    echo "**Category:** $CONTEXT_CATEGORY"
    echo
    echo "---"
    echo
    cat "$parsed_md"
  } > "$final_md"
}

main() {
  parse_args "$@"
  ensure_dependencies

  local raw_json="$INPUT_SOURCE"
  local temp_json=""
  local temp_md="/tmp/teams_parsed_$$.md"

  if [[ "$INPUT_MODE" == "url" ]]; then
    [[ -n "$GRAPH_TOKEN" ]] || { echo "Error: missing graph token for URL mode" >&2; exit 1; }
    temp_json="/tmp/teams_raw_$$.json"

    local replies_flag=""
    if [[ "$INCLUDE_REPLIES" -eq 1 ]]; then
      replies_flag="--include-replies"
    fi

    python3 "$FETCH_SCRIPT" \
      --url "$INPUT_SOURCE" \
      --output "$temp_json" \
      --token "$GRAPH_TOKEN" \
      $replies_flag

    raw_json="$temp_json"
  fi

  python3 "$PARSE_SCRIPT" --input "$raw_json" --output "$temp_md"

  local out_md="$OUTPUT_MD"
  if [[ -z "$out_md" ]]; then
    out_md="$(build_default_output)"
  fi

  generate_artifact "$temp_md" "$out_md"

  rm -f "$temp_md"
  if [[ -n "$temp_json" ]]; then
    rm -f "$temp_json"
  fi

  echo "Teams session sync complete."
  echo "- Input:  $INPUT_SOURCE"
  echo "- Output: $out_md"
}

main "$@"
