
#for dotfiles
export XDG_CONFIG_HOME="$HOME/.config"
#for specific data
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
#for cached files
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
