#!/bin/bash

set -e

# create process prefix: /usr/bin/python3 /usr/bin/tmuxp
tmuxterm_prefix="$(which python3) $(which tmuxp)"
if [[ ! $(pgrep -u $UID -f "$tmuxterm_prefix load term-ws1") ]]; then
  i3-msg "workspace number 1 term; append_layout $HOME/.config/i3/workspace1-term.json"
  i3-msg "exec --no-startup-id $HOME/.config/i3/scripts/start-tmuxp.sh term-ws1"
fi
if [[ ! $(pgrep -u $UID -x firefox) ]]; then
  #firefox only web workspace
  i3-msg "workspace number 2 web; append_layout $HOME/.config/i3/workspace2-web.json"
  #  firefox &
  i3-msg "exec --no-startup-id firefox"
fi
if [[ ! $(pgrep -u $UID -f "$tmuxterm_prefix load term-dev") ]]; then
  i3-msg "workspace number 3 dev; append_layout $HOME/.config/i3/workspace3-dev.json"
  i3-msg "exec --no-startup-id $HOME/.config/i3/scripts/start-tmuxp.sh term-dev"
fi

i3-msg "workspace number 6 web; append_layout $HOME/.config/i3/workspace6-web.json"
