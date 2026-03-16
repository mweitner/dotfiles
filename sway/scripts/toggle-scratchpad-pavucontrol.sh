#!/usr/bin/env bash
set -euo pipefail

MARK="scratchpad-pavucontrol"

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

if window_exists; then
  swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
  swaymsg "[con_mark=\"${MARK}\"] move position center"
  exit 0
fi

swaymsg 'exec pavucontrol' >/dev/null

for _ in $(seq 1 30); do
  if window_exists; then
    swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
    swaymsg "[con_mark=\"${MARK}\"] move position center"
    exit 0
  fi
  sleep 0.1
done
