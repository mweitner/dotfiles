#!/usr/bin/env bash
set -euo pipefail

MARK="scratchpad-vpn"
APP_ID="vpn-float"
WIDTH="${VPN_WIDTH:-1000}"
HEIGHT="${VPN_HEIGHT:-650}"
VPN_HOST="${1:-lis01.vpn.liebherr.com}"

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

show_window() {
  swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
  swaymsg "[con_mark=\"${MARK}\"] resize set ${WIDTH} ${HEIGHT}"
  swaymsg "[con_mark=\"${MARK}\"] move position center"
}

if window_exists; then
  show_window
  exit 0
fi

swaymsg "exec foot --app-id ${APP_ID} --title ${APP_ID} -e $HOME/.local/bin/vpn-on ${VPN_HOST}" >/dev/null

for _ in $(seq 1 40); do
  if window_exists; then
    show_window
    exit 0
  fi
  sleep 0.1
done
