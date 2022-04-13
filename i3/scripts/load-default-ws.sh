#!/bin/bash

set -e

if [[ ! $(pgrep -u $UID -f "urxvt -name urxvt-term") ]]; then
  i3-msg "workspace number 1 term; append_layout $HOME/.config/i3/workspace1-term.json"
  i3-msg "exec --no-startup-id $HOME/.config/i3/scripts/start-urxvt.sh urxvt-term"
  # alternative is calling script directly but had strange behaviour
  # where terminal was opened at dev workspace instead term workspace
  # most likely a timing issue which is solved if i3 api is used!!!
  #. $HOME/.config/i3/scripts/start-urxvt.sh urxvt-term
fi
if [[ ! $(pgrep -u $UID -x firefox) ]]; then
  i3-msg "workspace number 2 web; append_layout $HOME/.config/i3/workspace2-web.json"
  #  firefox &
  i3-msg "exec --no-startup-id firefox"
  i3-msg "exec --no-startup-id $HOME/.config/i3/scripts/start-urxvt.sh urxvt-web"
  #. $HOME/.config/i3/scripts/start-urxvt.sh urxvt-web
fi
if [[ ! $(pgrep -u $UID -f "urxvt -name urxvt-dev") ]]; then
  i3-msg "workspace number 3 dev; append_layout $HOME/.config/i3/workspace3-dev.json"
  i3-msg "exec --no-startup-id $HOME/.config/i3/scripts/start-urxvt.sh urxvt-dev"
  #. $HOME/.config/i3/scripts/start-urxvt.sh urxvt-dev
fi

