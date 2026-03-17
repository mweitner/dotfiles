#!/usr/bin/env bash
# Dev workspace startup for Sway.
# Opens tmux sessions (via tmuxp) and apps across all workspaces.
# Safe to re-run: skips anything already running.
set -euo pipefail

TMUXP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmuxp"

# Pre-create a tmux session in detached mode if it doesn't exist yet.
load_session() {
  local name="$1"
  if ! tmux has-session -t "$name" 2>/dev/null; then
    tmuxp load -d "$TMUXP_DIR/$name.yaml"
  fi
}

# Pre-create all tmux sessions in the background.
load_session "1-tools"
load_session "3-dev"
load_session "4-dev"
load_session "5-tools"
load_session "7-targets"

# Helper: switch to a named workspace and exec an app there.
# Names must match the set $wsN variables in sway/config.
ws_exec() {
  local ws="$1" name="$2"; shift 2
  swaymsg "workspace number $ws $name"
  swaymsg "exec $*"
  sleep 0.3
}

# ws1 term — 1-tools tmux session
ws_exec 1 term "foot -e tmux attach-session -t 1-tools"

# ws2 web — Firefox
if ! pgrep -u "$UID" -x firefox >/dev/null 2>&1; then
  ws_exec 2 web firefox
fi

# ws3 dev — 3-dev tmux session
ws_exec 3 dev "foot -e tmux attach-session -t 3-dev"

# ws4 vm — 4-dev tmux session
ws_exec 4 vm "foot -e tmux attach-session -t 4-dev"

# ws5 rdp — 5-tools tmux session
ws_exec 5 rdp "foot -e tmux attach-session -t 5-tools"

# ws6 web2 — Google Chrome (falls back to Chromium)
if ! pgrep -u "$UID" -x "google-chrome-stable\|chromium\|chromium-browser" >/dev/null 2>&1; then
  if command -v google-chrome-stable >/dev/null 2>&1; then
    ws_exec 6 web2 google-chrome-stable
  elif command -v chromium >/dev/null 2>&1; then
    ws_exec 6 web2 chromium
  fi
fi

# ws7 dev2 — 7-targets tmux session
ws_exec 7 dev2 "foot -e tmux attach-session -t 7-targets"

# ws8, ws9 — reserved (nothing launched)

# ws10 dev5 — VS Code
if ! pgrep -u "$UID" -x code >/dev/null 2>&1; then
  ws_exec 10 dev5 code
fi

# Return focus to ws1
swaymsg "workspace number 1 term"
