#!/usr/bin/env bash
set -euo pipefail

TITLE="scratchpad-term"
MARK="scratchpad-term"

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

# If scratchpad terminal already exists, show and center it.
if window_exists; then
  swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
  swaymsg "[con_mark=\"${MARK}\"] move position center"
  exit 0
fi

# Otherwise launch it; for_window rules in sway/config move it to scratchpad.
swaymsg "exec foot --title ${TITLE} -e fish" >/dev/null

# Wait briefly for the new window to appear, then show it from scratchpad.
for _ in $(seq 1 30); do
  if window_exists; then
    swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
    swaymsg "[con_mark=\"${MARK}\"] move position center"
    exit 0
  fi
  sleep 0.1
done
