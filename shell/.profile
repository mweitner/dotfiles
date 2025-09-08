#
# .profile common user specific shell configuration
#
# This config shall be sourced independent of type of shell
# For example a bash shell would source .profile by .bash_profile
#
# When using a display manager (like LightDM), most XDG/DBus/Systemd
# environment variables are handled automatically by the display manager
# and systemd-logind. This file can focus on general shell settings.

# Example: Set a default umask
# umask 022

# Example: Add user-specific executables to PATH (if not already handled by /etc/profile)
# It's common for ~/.local/bin to be added by default on modern systems, but you can explicitly add:
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Example: Set a default editor (if not already in your Zsh configs)
# export EDITOR=nvim
# export VISUAL=nvim

# Any other general environment variables or functions you want available
# to all login shells, regardless of graphical session.

# Example: If you have custom profile.d scripts (unlikely if not using standard systemd-user.sh)
# if [ -d "$HOME/.profile.d" ]; then
#   for i in "$HOME/.profile.d/"*.sh; do
#     if [ -r "$i" ]; then
#       . "$i"
#     fi
#   done
#   unset i
# fi
. "$HOME/.cargo/env"
