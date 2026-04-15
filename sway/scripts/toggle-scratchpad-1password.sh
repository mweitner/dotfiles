#!/usr/bin/env bash
set -euo pipefail

MARK="scratchpad-1password"

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

app_window_exists() {
  swaymsg -t get_tree | jq -e '.. | objects | select(.app_id? == "1password" or .window_properties?.class? == "1Password")' >/dev/null
}

tag_existing_window() {
  swaymsg '[app_id="1password"] mark --add scratchpad-1password' >/dev/null
  swaymsg '[class="1Password"] mark --add scratchpad-1password' >/dev/null
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

# Recover if 1Password exists but does not have the expected mark.
if app_window_exists; then
  tag_existing_window
  if window_exists; then
    swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
    swaymsg "[con_mark=\"${MARK}\"] move position center"
    exit 0
  fi
fi

# Launch 1Password; for_window rules in sway/config will mark and move it.
swaymsg 'exec 1password' >/dev/null
swaymsg "[con_mark=\"${MARK}\"] resize set 1000 760"

for _ in $(seq 1 30); do
  apply_fallback_window_rules
  tag_existing_window

  if window_exists; then
    swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
    swaymsg "[con_mark=\"${MARK}\"] move position center"
    exit 0
  fi
  sleep 0.1
done
