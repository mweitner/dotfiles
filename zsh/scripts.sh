#!/bin/zsh

compress() {
  tar xvzf $1.tar.gz $1
}

ftmuxp() {
    if [[ -n $TMUX ]]; then
        return
    fi
    
    # get the IDs
    ID="$(ls $XDG_CONFIG_HOME/tmuxp | sed -e 's/\.yml$//')"
    if [[ -z "$ID" ]]; then
        tmux new-session
    fi

    create_new_session="Create New Session"

    ID="${create_new_session}\n$ID"
    ID="$(echo $ID | fzf | cut -d: -f1)"

    if [[ "$ID" = "${create_new_session}" ]]; then
        tmux new-session
    elif [[ -n "$ID" ]]; then
        # Rename the current urxvt tab to session name
        printf '\033]777;tabbedx;set_tab_name;%s\007' "$ID"
        tmuxp load "$ID"
    fi
}

tmux-new-window() {
  #
  # param[1] session - name
  # param[2] wd - working directory (full path)
  # param[3, optional] window - name (default: wd last path name)
  #
  if [[ -z "$TMUX" ]]; then
    return
  fi

  session=$1
  wd=$2
  window=$3
  if [[ -z "$window" ]]; then
    window=$(basename $wd | sed 's/-//g; s/\.//g')
  fi

  last_window_name=$(tmux list-windows -t $session -F \#w | tail -n1)
  if [[ -z "$last_window_name" ]]; then
    echo "no window must not be possible as there is always window:0"
  fi

  echo "create new window: session: $session:$window, wd: $wd"
  tmux new-window -t $session -n $window
  tmux send-keys -t $session:$window "cd $wd" Enter
  tmux send-keys -t $session:$window "vim" Enter
  tmux split-window -v -t $session:$window -p 30
  #pane index starts with 1
  tmux send-keys -t $session:$window.2 "cd $wd" Enter C-g
  tmux select-pane -t $session:$window.1
}

wikipedia() {
  #lynx -vikeys -accept_all_cookies "https://en.wikipedia.org/wiki?search=$@"
  qutebrowser "https://en.wikipedia.org/wiki?search=$@"
}

duckduckgo() {
  #lynx -vikeys -accept_all_cookies "https://lite.duckduckgo.com/lite/?q='$@'"
  qutebrowser "https://lite.duckduckgo.com/lite/?q='$@'"
}

setupwifi() {
  wifi_index=$1
  if [[ -z "$wifi_index" ]]; then
    wifi_index="1"
  fi

  wifi_device_name="wlan${wifi_index}"
  sudo ip link set down ${wifi_device_name}
  sudo ip link set ${wifi_device_name} name wlan0
  sudo ip link set up wlan0
}
