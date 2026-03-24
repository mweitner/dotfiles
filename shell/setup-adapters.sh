#!/usr/bin/env bash
set -euo pipefail

#
# setup-adapters.sh — Convenient wrapper for setup-machine-network-profiles.sh
#
# Maps named adapters (adapter-a, adapter-b, adapter-c) to their MACs.
# Simplifies profile assignment by adapter name instead of MAC.
#
# Usage:
#   setup-adapters.sh --adapter a --group lpo [--dry-run]
#   setup-adapters.sh --adapter a,b,c --group crane --group concrete [--dry-run]
#   setup-adapters.sh --adapter c --profile Machine-lpo-dc5 [--dry-run]
#   setup-adapters.sh --list-adapters
#

# Adapter registry: name -> MAC
declare -A ADAPTERS=(
  [a]="00:E0:4C:B8:28:B5"    # enx00e04cb828b5
  [b]="00:E0:4C:68:05:C8"    # enx00e04c6805c8
  [c]="3C:49:37:05:47:46"    # enx3c4937054746
)

DRY_RUN=0
SELECTED_ADAPTER=""
GROUP_OVERRIDES=()
PROFILE_OVERRIDES=()

usage() {
  cat <<'EOF'
Usage:
  setup-adapters.sh --adapter <a|b|c> [--group <group>] ... [--profile <name=adapter>] ... [--dry-run]
  setup-adapters.sh --list-adapters

Options:
  --adapter <name>           Primary adapter to use (a, b, or c)
  --group <group>            Override adapter for a specific group (e.g. lpo=a,b or lpo=c)
  --profile <name>           Override adapter for a specific profile (e.g. Machine-lpo-dc5=c)
  --list-adapters            Show registered adapters and MACs
  --dry-run                  Print nmcli commands without executing them
  -h, --help                 Show this help

Groups: crane, concrete, mining, lpo, ho

Examples:
  # Use adapter-b for all profiles
  setup-adapters.sh --adapter b

  # Use adapter-a by default, but adapter-c for lpo group
  setup-adapters.sh --adapter a --group lpo=c

  # Use adapter-c only for Machine-lpo-dc5, rest on adapter-a
  setup-adapters.sh --adapter a --profile Machine-lpo-dc5=c --group lpo

  # Use adapter-a for crane, adapter-b for concrete, adapter-c for mining and home-office simulation
  setup-adapters.sh --group crane=a --group concrete=b --group mining=c --group ho=c
EOF
}

list_adapters() {
  cat <<'EOF'
Registered adapters:
EOF
  for name in $(printf '%s\n' "${!ADAPTERS[@]}" | sort); do
    printf '  adapter-%s:  %s\n' "$name" "${ADAPTERS[$name]}"
  done
}

resolve_adapter() {
  local name="$1"
  if [ -z "${ADAPTERS[$name]:-}" ]; then
    echo "Error: unknown adapter '$name'. Valid: a, b, c" >&2
    exit 1
  fi
  printf '%s' "${ADAPTERS[$name]}"
}

parse_group_override() {
  local override="$1"
  local group adapter_name mac

  if ! printf '%s' "$override" | grep -q '='; then
    echo "Error: group override must be <group=adapter>, got '$override'" >&2
    exit 1
  fi

  group="${override%%=*}"
  adapter_name="${override#*=}"

  if [ -z "$group" ] || [ -z "$adapter_name" ]; then
    echo "Error: group override must be <group=adapter>, got '$override'" >&2
    exit 1
  fi

  mac="$(resolve_adapter "$adapter_name")"
  printf '%s=%s\n' "$group" "$mac"
}

parse_profile_override() {
  local override="$1"
  local profile adapter_name mac

  if ! printf '%s' "$override" | grep -q '='; then
    echo "Error: profile override must be <profile=adapter>, got '$override'" >&2
    exit 1
  fi

  profile="${override%%=*}"
  adapter_name="${override#*=}"

  if [ -z "$profile" ] || [ -z "$adapter_name" ]; then
    echo "Error: profile override must be <profile=adapter>, got '$override'" >&2
    exit 1
  fi

  mac="$(resolve_adapter "$adapter_name")"
  printf '%s=%s\n' "$profile" "$mac"
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --adapter)
      SELECTED_ADAPTER="$(resolve_adapter "${2:-}")" || exit 1
      shift 2
      ;;
    --group)
      GROUP_OVERRIDES+=("$(parse_group_override "${2:-}")")
      shift 2
      ;;
    --profile)
      PROFILE_OVERRIDES+=("$(parse_profile_override "${2:-}")")
      shift 2
      ;;
    --list-adapters)
      list_adapters
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$SELECTED_ADAPTER" ] && [ "${#GROUP_OVERRIDES[@]}" -eq 0 ] && [ "${#PROFILE_OVERRIDES[@]}" -eq 0 ]; then
  echo "Error: provide --adapter and/or --group/--profile." >&2
  usage
  exit 1
fi

# Build wrapper script command
SETUP_PROFILES_SCRIPT="$HOME/dotfiles/shell/setup-machine-network-profiles.sh"
if [ ! -f "$SETUP_PROFILES_SCRIPT" ]; then
  echo "Error: setup-machine-network-profiles.sh not found at $SETUP_PROFILES_SCRIPT" >&2
  exit 1
fi

CMD=("$SETUP_PROFILES_SCRIPT")

if [ -n "$SELECTED_ADAPTER" ]; then
  CMD+=(--usb-mac "$SELECTED_ADAPTER")
fi

for override in "${GROUP_OVERRIDES[@]}"; do
  CMD+=(--group-mac "$override")
done

for override in "${PROFILE_OVERRIDES[@]}"; do
  CMD+=(--profile-mac "$override")
done

if [ "$DRY_RUN" -eq 1 ]; then
  CMD+=(--dry-run)
fi

# Execute
bash "${CMD[@]}"
