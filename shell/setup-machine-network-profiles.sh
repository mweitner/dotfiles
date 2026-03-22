#!/usr/bin/env bash
set -euo pipefail

# Create/refresh NetworkManager profiles for machine-network use cases.
# Profiles are bound by adapter MAC, so they work regardless of interface name
# (for example enx00e..., enp0s20f0u2u3, ...).

USB_MAC=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  setup-machine-network-profiles.sh --usb-mac <MAC> [--dry-run]

Options:
  --usb-mac <MAC>   USB2Ethernet adapter MAC, e.g. 00:E0:4C:B8:28:B5
  --dry-run         Print nmcli commands without executing them
  -h, --help        Show help

Notes:
  - Existing profiles with the same name are replaced.
  - All profiles are set to autoconnect=no and ipv4.method=manual.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --usb-mac)
      USB_MAC="${2:-}"
      shift 2
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

if [ -z "$USB_MAC" ]; then
  echo "Error: --usb-mac is required." >&2
  usage
  exit 1
fi

if ! command -v nmcli >/dev/null 2>&1; then
  echo "Error: nmcli not found. Install NetworkManager." >&2
  exit 1
fi

if ! printf '%s' "$USB_MAC" | grep -Eiq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'; then
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

  # Delete first so reruns are deterministic.
  run_nmcli connection delete "$name" >/dev/null 2>&1 || true

  if [ -n "$gateway" ]; then
    run_nmcli connection add type ethernet con-name "$name" \
      802-3-ethernet.mac-address "$USB_MAC" \
      ipv4.method manual \
      ipv4.addresses "$addresses" \
      ipv4.gateway "$gateway" \
      ipv4.route-metric 1 \
      ipv4.never-default yes \
      connection.autoconnect no
  else
    run_nmcli connection add type ethernet con-name "$name" \
      802-3-ethernet.mac-address "$USB_MAC" \
      ipv4.method manual \
      ipv4.addresses "$addresses" \
      ipv4.route-metric 1 \
      ipv4.never-default yes \
      connection.autoconnect no
  fi
}

# Legacy machine networks
replace_profile "Machine-crane-rope-testrig-GW" "192.168.32.1/23" ""
replace_profile "Machine-crane-rope-testrig-TU" "192.168.32.150/23,169.254.1.41/16" ""

replace_profile "Machine-concrete-mixing-plant-GW" "192.168.5.120/24" ""
replace_profile "Machine-concrete-mixing-plant-TU" "192.168.5.211/24,169.254.1.211/16,192.168.5.212/24,169.254.1.212/16" "192.168.5.120"

replace_profile "Machine-mining-excavator-GW" "192.168.3.1/24" ""
replace_profile "Machine-mining-excavator-TU" "192.168.3.101/24,169.254.1.41/16,192.168.3.102/24,169.254.1.42/16,192.168.3.103/24,169.254.1.43/16,192.168.3.104/24,169.254.1.44/16" "192.168.3.1"

# LPO / battery-trailer network
replace_profile "Machine-lpo-CSM" "192.168.2.200/24" ""
replace_profile "Machine-lpo-CSM-GW" "192.168.2.1/24" ""
replace_profile "Machine-lpo-dc5" "192.168.2.130/24" ""

if [ "$DRY_RUN" -eq 0 ]; then
  echo "Created/updated Machine-* profiles bound to MAC $USB_MAC"
  echo "Check with: nmcli connection show | grep '^Machine-'"
fi
