#!/usr/bin/env bash
set -euo pipefail

TITLE="scratchpad-term"
MARK="scratchpad-term"
SESSION_NAME="term-scratchpad"
TMUXP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmuxp"
SCRATCHPAD_WIDTH="${SCRATCHPAD_WIDTH:-1700}"
SCRATCHPAD_HEIGHT="${SCRATCHPAD_HEIGHT:-1050}"

show_scratchpad() {
  swaymsg "[con_mark=\"${MARK}\"] scratchpad show"
  swaymsg "[con_mark=\"${MARK}\"] resize set ${SCRATCHPAD_WIDTH} ${SCRATCHPAD_HEIGHT}"
  swaymsg "[con_mark=\"${MARK}\"] move position center"
}

window_exists() {
  swaymsg -t get_marks | grep -q "${MARK}"
}

ensure_tmux_session() {
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    return 0
  fi

  if command -v tmuxp >/dev/null 2>&1 && [[ -f "$TMUXP_DIR/$SESSION_NAME.yml" ]]; then
    tmuxp load -d "$TMUXP_DIR/$SESSION_NAME.yml"
  else
    tmux new-session -d -s "$SESSION_NAME" -c "$HOME"
  fi
}

# If scratchpad terminal already exists, show and center it.
if window_exists; then
  show_scratchpad
  exit 0
fi

# Otherwise launch it; for_window rules in sway/config move it to scratchpad.
ensure_tmux_session
swaymsg "exec foot --title ${TITLE} -e tmux attach-session -t ${SESSION_NAME}" >/dev/null

# Wait briefly for the new window to appear, then show it from scratchpad.
for _ in $(seq 1 30); do
  if window_exists; then
    show_scratchpad
    exit 0
  fi
  sleep 0.1
done
