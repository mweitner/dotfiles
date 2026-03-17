#!/usr/bin/env bash
set -euo pipefail

TITLE="nmtui-float"
MARK="scratchpad-nmtui"
WIDTH="${NMTUI_WIDTH:-1400}"
HEIGHT="${NMTUI_HEIGHT:-1000}"

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

show_window() {
  swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
  swaymsg "[con_mark=\"${MARK}\"] move position center"
}

if window_exists; then
  show_window
  exit 0
fi

swaymsg "exec foot --app-id ${TITLE} --title ${TITLE} -e /usr/bin/nmtui" >/dev/null

for _ in $(seq 1 40); do
  if window_exists; then
    show_window
    exit 0
  fi
  sleep 0.1
done
