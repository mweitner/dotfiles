#!/bin/sh
set -x # Keep debugging for now
exec > "$HOME/.xinitrc.log" 2>&1 # Redirect all output to log file

echo "--- Starting .xinitrc at $(date) (Simplified, Environment Focus) ---"

# --- Ensure XDG_RUNTIME_DIR is set ---
# This ensures it's definitely set within the .xinitrc context.
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    if ! [ -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 0700 "$XDG_RUNTIME_DIR"
    fi
fi
echo "Current XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"

# --- Explicitly set XDG session variables for logind ---
# These are crucial for systemd-logind to recognize the session type.
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=i3
if [ -z "$XDG_SESSION_ID" ]; then
    # Attempt to derive from the current TTY's session ID
    export XDG_SESSION_ID=$(loginctl | grep $(whoami) | awk '{print $1}' | head -n 1)
fi
echo "XDG_SESSION_TYPE: $XDG_SESSION_TYPE"
echo "XDG_SESSION_DESKTOP: $XDG_SESSION_DESKTOP"
echo "XDG_SESSION_ID: $XDG_SESSION_ID"


# --- Start DBus session if not already running (CRITICAL for X session) ---
# This ensures DBUS_SESSION_BUS_ADDRESS is set FOR THIS X SESSION.
echo "Checking DBUS_SESSION_BUS_ADDRESS before dbus-launch in .xinitrc: $DBUS_SESSION_BUS_ADDRESS"
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    echo "DBUS_SESSION_BUS_ADDRESS is empty in .xinitrc. Running dbus-launch to establish it..."
    eval $(dbus-launch --exit-with-session --sh-syntax)
    echo "DBUS_SESSION_BUS_ADDRESS after dbus-launch in .xinitrc: $DBUS_SESSION_BUS_ADDRESS"
else
    echo "DBUS_SESSION_BUS_ADDRESS was already set when .xinitrc started: $DBUS_SESSION_BUS_ADDRESS"
fi


# --- Start gnome-keyring-daemon (Must happen AFTER DBUS_SESSION_BUS_ADDRESS is set) ---
echo "Starting gnome-keyring-daemon..."
# Ensure any old control sockets are gone before attempting to start
rm -f "$XDG_RUNTIME_DIR"/keyring/control
# Note: Removed --daemonize, as `eval $(...)` for `gnome-keyring-daemon --start`
# is often enough to background it while still getting its output.
KEYRING_CMD="/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh"
echo "Executing keyring command: $KEYRING_CMD"
KEYRING_OUTPUT=$(eval "$KEYRING_CMD" 2>&1)
echo "Keyring daemon output: $KEYRING_OUTPUT"

# Export SSH_AUTH_SOCK and GPG_AGENT_INFO from gnome-keyring-daemon's output
# This must be explicit if gnome-keyring-daemon outputs these for eval.
export SSH_AUTH_SOCK
export GPG_AGENT_INFO
echo "SSH_AUTH_SOCK after keyring: $SSH_AUTH_SOCK"
echo "GPG_AGENT_INFO after keyring: $GPG_AGENT_INFO"


# --- Update the DBus activation environment (IMPORTANT for systemd --user/Snap) ---
echo "Updating dbus activation environment..."
# This command explicitly tells the *running* systemd --user instance about the new DBus address.
# This is the primary way we'll try to get Snap's cgroup issue resolved without systemd-run.
dbus-update-activation-environment --systemd --all || echo 'dbus-update-activation-environment failed or skipped.'


echo "--- Running graphical desktop commands ---"
xrdb -merge "$HOME/.config/X11/.Xresources"
urxvtd -o -q -f &
udiskie -A &

echo "--- Executing i3 ---"
# This is the final exec, launching i3 directly.
# We are relying on dbus-update-activation-environment above to inform systemd.
exec i3

# as of wiki.archlinux.org xinitrc
# mweitner however uncommented now because had not effect
#. /etc/X11/Xsession
