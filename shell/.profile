#
# .profile common user specific shell configuration
#
# This config shall be sourced independent of type of shell
# For example a bash shell would source .profile by .bash_profile
#

# ~/.profile: executed by the command interpreter for login shells.
# This file is sourced by Zsh (if configured in .zshrc/.zprofile) for login shells.

# --- Ensure XDG_RUNTIME_DIR is set and managed by systemd-logind ---
# This directory is crucial for modern desktop components and Snap applications.
if [ -z "$XDG_RUNTIME_DIR" ]; then
    # Use loginctl if available and we are in a session to get the official path
    if command -v loginctl >/dev/null 2>&1 && [ -n "$XDG_SESSION_ID" ]; then
        export XDG_RUNTIME_DIR=$(loginctl show-session "$XDG_SESSION_ID" -p RuntimePath --value)
    fi
    # Fallback if loginctl doesn't provide it or not in a session
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        if ! [ -d "$XDG_RUNTIME_DIR" ]; then
            mkdir -p "$XDG_RUNTIME_DIR"
            chmod 0700 "$XDG_RUNTIME_DIR"
        fi
    fi
fi

# --- Set XDG session types for systemd-logind recognition ---
# This helps logind understand it's a graphical X11 session for i3
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=i3

# --- Crucial for systemd --user DBus session and Snap integration ---
# Attempt to start the systemd --user session and get its DBus address.
# This usually works well after a TTY login that PAM has processed.
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    if command -v systemctl >/dev/null 2>&1; then
        # Start the user's systemd manager if it's not running
        # The '|| true' prevents the script from exiting if this fails, allowing fallback.
        systemctl --user start default.target || true
        
        # Get the DBus address for the user's systemd instance
        # This is the DBus instance that gnome-keyring and Snaps want to talk to.
        USER_BUS_ADDRESS=$(systemctl --user show-environment | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d '=' -f 2-)
        if [ -n "$USER_BUS_ADDRESS" ]; then
            export DBUS_SESSION_BUS_ADDRESS="$USER_BUS_ADDRESS"
        else
            # Fallback to dbus-launch if systemd-user's DBus address isn't readily available.
            # This might indicate a deeper systemd --user issue if it's still needed.
            # dbus-launch will start a *new* D-Bus session, not necessarily the systemd --user one,
            # but it's better than no D-Bus address for graphical apps.
            if command -v dbus-launch >/dev/null 2>&1; then
                eval $(dbus-launch --sh-syntax --exit-with-session)
            fi
        fi
    fi
fi

# --- Ensure SSH_AUTH_SOCK and GPG_AGENT_INFO are passed from systemd --user, if available ---
# These often come from gnome-keyring-daemon managed by systemd --user
if [ -z "$SSH_AUTH_SOCK" ] && command -v systemctl >/dev/null 2>&1; then
    export SSH_AUTH_SOCK=$(systemctl --user show-environment | grep '^SSH_AUTH_SOCK=' | cut -d '=' -f 2-)
fi
if [ -z "$GPG_AGENT_INFO" ] && command -v systemctl >/dev/null 2>&1; then
    export GPG_AGENT_INFO=$(systemctl --user show-environment | grep '^GPG_AGENT_INFO=' | cut -d '=' -f 2-)
fi

# --- Ensure XDG_SESSION_ID is set (important for logind) ---
if [ -z "$XDG_SESSION_ID" ]; then
    # Get the ID of the current login session (TTY)
    export XDG_SESSION_ID=$(loginctl | grep $(whoami) | awk '{print $1}' | head -n 1)
    # This might need refinement if loginctl output is ambiguous with multiple sessions
fi
