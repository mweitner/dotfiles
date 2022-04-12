#!/bin/bash

set -e

if [[ ! $(pgrep -u $UID -f "urxvt -name urxvt-terms") ]]; then
  i3-msg "workspace number 1; append_layout $HOME/.config/i3/workspace1-terms.json"
  # this did not work 
  #i3-msg "exec --no-startup-id urxvt -name urxvt-terms"
  . $HOME/.config/i3/scripts/start-urxvt.sh urxvt-terms
fi
if [[ ! $(pgrep -u $UID -x firefox) ]]; then
  i3-msg "workspace number 2; append_layout $HOME/.config/i3/workspace2-web.json"
  firefox &
  ./$HOME/.config/i3/scripts/start-urxvt.sh urxvt-web
fi
if [[ ! $(pgrep -u $UID -f "urxvt -name urxvt-dev") ]]; then
  i3-msg "workspace number 3; append_layout $HOME/.config/i3/workspace3-dev.json"
  . $HOME/.config/i3/scripts/start-urxvt.sh urxvt-dev
fi

