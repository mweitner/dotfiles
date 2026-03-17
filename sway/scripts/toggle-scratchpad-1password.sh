#!/usr/bin/env bash
set -euo pipefail

MARK="scratchpad-1password"

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

window_is_focused() {
  swaymsg -t get_tree | jq -e ".. | objects | select(.focused? == true) | (.marks? // []) | index(\"${MARK}\")" >/dev/null
}

apply_fallback_window_rules() {
  swaymsg '[app_id="(?i).*1password.*"] floating enable, resize set 1000 760, mark --add scratchpad-1password, move scratchpad, border none' >/dev/null
  swaymsg '[class="(?i).*1password.*"] floating enable, resize set 1000 760, mark --add scratchpad-1password, move scratchpad, border none' >/dev/null
  swaymsg '[instance="(?i).*1password.*"] floating enable, resize set 1000 760, mark --add scratchpad-1password, move scratchpad, border none' >/dev/null
}

if window_exists; then
  # If the window is already focused and visible, hide it back to scratchpad.
  if window_is_focused; then
    swaymsg "[con_mark=\"${MARK}\"] move scratchpad"
    exit 0
  fi

  swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
  swaymsg "[con_mark=\"${MARK}\"] move position center"
  exit 0
fi

# Launch 1Password; for_window rules in sway/config will mark and move it.
swaymsg 'exec 1password' >/dev/null
swaymsg "[con_mark=\"${MARK}\"] resize set 1000 760"

for _ in $(seq 1 30); do
  apply_fallback_window_rules

  if window_exists; then
    swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
    swaymsg "[con_mark=\"${MARK}\"] move position center"
    exit 0
  fi
  sleep 0.1
done
