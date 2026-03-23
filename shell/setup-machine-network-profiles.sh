#!/usr/bin/env bash
set -euo pipefail

# Create/refresh NetworkManager profiles for machine-network use cases.
# Profiles are bound by adapter MAC, so they work regardless of interface name
# (for example enx00e..., enp0s20f0u2u3, ...).

USB_MAC=""
DRY_RUN=0

declare -A GROUP_MAC_OVERRIDES=()
declare -A PROFILE_MAC_OVERRIDES=()
declare -a ONLY_GROUPS=()

usage() {
  cat <<'EOF'
Usage:
  setup-machine-network-profiles.sh --usb-mac <MAC> [--dry-run]
  setup-machine-network-profiles.sh --group-mac <group=MAC> [--group-mac <group=MAC> ...] [--dry-run]
  setup-machine-network-profiles.sh --usb-mac <MAC> --group-mac <group=MAC> [--profile-mac <profile=MAC> ...]

Options:
  --usb-mac <MAC>           Default USB2Ethernet adapter MAC for all profiles
  --group-mac <group=MAC>   Override adapter MAC for a profile group
  --profile-mac <name=MAC>  Override adapter MAC for an exact profile name
  --only-group <group>      Create/update profiles only for this group (repeatable)
  --list-groups             Print known groups and exit
  --dry-run                 Print nmcli commands without executing them
  -h, --help        Show help

Notes:
  - Existing profiles with the same name are replaced.
  - All profiles are set to autoconnect=no and ipv4.method=manual.
  - Precedence for MAC selection is: profile override > group override > --usb-mac.
  - Known groups: crane, concrete, mining, lpo.
EOF
}

list_groups() {
  cat <<'EOF'
crane
concrete
mining
lpo
EOF
}

is_valid_mac() {
  printf '%s' "$1" | grep -Eiq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'
}

parse_mapping_arg() {
  local mapping="$1"
  local key
  local mac

  if ! printf '%s' "$mapping" | grep -q '='; then
    echo "Error: mapping must be in <key=MAC> format: $mapping" >&2
    exit 1
  fi

  key="${mapping%%=*}"
  mac="${mapping#*=}"

  if [ -z "$key" ] || [ -z "$mac" ]; then
    echo "Error: mapping must be in <key=MAC> format: $mapping" >&2
    exit 1
  fi

  if ! is_valid_mac "$mac"; then
    echo "Error: invalid MAC format in mapping '$mapping'" >&2
    exit 1
  fi

  printf '%s\n%s\n' "$key" "$mac"
}

is_group_selected() {
  local group="$1"
  local g

  if [ "${#ONLY_GROUPS[@]}" -eq 0 ]; then
    return 0
  fi

  for g in "${ONLY_GROUPS[@]}"; do
    if [ "$g" = "$group" ]; then
      return 0
    fi
  done

  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --usb-mac)
      USB_MAC="${2:-}"
      shift 2
      ;;
    --group-mac)
      mapfile -t parsed < <(parse_mapping_arg "${2:-}")
      GROUP_MAC_OVERRIDES["${parsed[0]}"]="${parsed[1]}"
      shift 2
      ;;
    --profile-mac)
      mapfile -t parsed < <(parse_mapping_arg "${2:-}")
      PROFILE_MAC_OVERRIDES["${parsed[0]}"]="${parsed[1]}"
      shift 2
      ;;
    --only-group)
      ONLY_GROUPS+=("${2:-}")
      shift 2
      ;;
    --list-groups)
      list_groups
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

if [ -z "$USB_MAC" ] && [ "${#GROUP_MAC_OVERRIDES[@]}" -eq 0 ] && [ "${#PROFILE_MAC_OVERRIDES[@]}" -eq 0 ]; then
  echo "Error: provide --usb-mac and/or --group-mac/--profile-mac." >&2
  usage
  exit 1
fi

if ! command -v nmcli >/dev/null 2>&1; then
  echo "Error: nmcli not found. Install NetworkManager." >&2
  exit 1
fi

if [ -n "$USB_MAC" ] && ! is_valid_mac "$USB_MAC"; then
  echo "Error: invalid MAC format: $USB_MAC" >&2
  exit 1
fi

run_nmcli() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] nmcli %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    nmcli "$@"
  fi
}

replace_profile() {
  local name="$1"
  local addresses="$2"
  local gateway="$3"
  local mac="$4"

  # Delete first so reruns are deterministic.
  run_nmcli connection delete "$name" >/dev/null 2>&1 || true

  if [ -n "$gateway" ]; then
    run_nmcli connection add type ethernet con-name "$name" \
      802-3-ethernet.mac-address "$mac" \
      ipv4.method manual \
      ipv4.addresses "$addresses" \
      ipv4.gateway "$gateway" \
      ipv4.route-metric 1 \
      ipv4.never-default yes \
      connection.autoconnect no
  else
    run_nmcli connection add type ethernet con-name "$name" \
      802-3-ethernet.mac-address "$mac" \
      ipv4.method manual \
      ipv4.addresses "$addresses" \
      ipv4.route-metric 1 \
      ipv4.never-default yes \
      connection.autoconnect no
  fi
}

pick_mac_for_profile() {
  local group="$1"
  local name="$2"

  if [ -n "${PROFILE_MAC_OVERRIDES[$name]:-}" ]; then
    printf '%s' "${PROFILE_MAC_OVERRIDES[$name]}"
    return 0
  fi

  if [ -n "${GROUP_MAC_OVERRIDES[$group]:-}" ]; then
    printf '%s' "${GROUP_MAC_OVERRIDES[$group]}"
    return 0
  fi

  printf '%s' "$USB_MAC"
}

apply_profile() {
  local group="$1"
  local name="$2"
  local addresses="$3"
  local gateway="$4"
  local mac

  if ! is_group_selected "$group"; then
    return 0
  fi

  mac="$(pick_mac_for_profile "$group" "$name")"
  if [ -z "$mac" ]; then
    echo "WARN: skipping '$name' (group '$group') because no MAC was resolved." >&2
    return 0
  fi

  replace_profile "$name" "$addresses" "$gateway" "$mac"
  echo "Mapped '$name' -> $mac"
}

# Legacy machine networks
apply_profile "crane" "Machine-crane-rope-testrig-GW" "192.168.32.1/23" ""
apply_profile "crane" "Machine-crane-rope-testrig-TU" "192.168.32.150/23,169.254.1.41/16" ""

apply_profile "concrete" "Machine-concrete-mixing-plant-GW" "192.168.5.120/24" ""
apply_profile "concrete" "Machine-concrete-mixing-plant-TU" "192.168.5.211/24,169.254.1.211/16,192.168.5.212/24,169.254.1.212/16" "192.168.5.120"

apply_profile "mining" "Machine-mining-excavator-GW" "192.168.3.1/24" ""
apply_profile "mining" "Machine-mining-excavator-TU" "192.168.3.101/24,169.254.1.41/16,192.168.3.102/24,169.254.1.42/16,192.168.3.103/24,169.254.1.43/16,192.168.3.104/24,169.254.1.44/16" "192.168.3.1"

# LPO / battery-trailer network
apply_profile "lpo" "Machine-lpo-CSM" "192.168.2.200/24" ""
apply_profile "lpo" "Machine-lpo-CSM-GW" "192.168.2.1/24" ""
apply_profile "lpo" "Machine-lpo-dc5" "192.168.2.130/24" ""

if [ "$DRY_RUN" -eq 0 ]; then
  if [ -n "$USB_MAC" ]; then
    echo "Created/updated Machine-* profiles with default MAC $USB_MAC"
  else
    echo "Created/updated Machine-* profiles using per-group/per-profile MAC mappings"
  fi
  echo "Check with: nmcli connection show | grep '^Machine-'"
fi
