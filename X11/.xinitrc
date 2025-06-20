#!/bin/sh
set -x
exec > "$HOME/.xinitrc.log" 2>&1 # Redirect all output to log file

echo "--- Starting .xinitrc at $(date) (Final Push for logind session) ---"

# Re-confirm/set XDG_RUNTIME_DIR
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    if ! [ -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 0700 "$XDG_RUNTIME_DIR"
    fi
fi
echo "Current XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"

# Explicitly set XDG session variables for logind, if they aren't already.
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=i3
if [ -z "$XDG_SESSION_ID" ]; then
    # Attempt to derive from the current TTY's session ID
    export XDG_SESSION_ID=$(loginctl | grep $(whoami) | awk '{print $1}' | head -n 1)
fi
echo "XDG_SESSION_TYPE: $XDG_SESSION_TYPE"
echo "XDG_SESSION_DESKTOP: $XDG_SESSION_DESKTOP"
echo "XDG_SESSION_ID: $XDG_SESSION_ID"

# Start DBus session if not already running (CRITICAL for X session)
echo "Checking DBUS_SESSION_BUS_ADDRESS before dbus-launch in .xinitrc: $DBUS_SESSION_BUS_ADDRESS"
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    echo "DBUS_SESSION_BUS_ADDRESS is empty in .xinitrc. Running dbus-launch to establish it..."
    eval $(dbus-launch --exit-with-session --sh-syntax)
    echo "DBUS_SESSION_BUS_ADDRESS after dbus-launch in .xinitrc: $DBUS_SESSION_BUS_ADDRESS"
else
    echo "DBUS_SESSION_BUS_ADDRESS was already set when .xinitrc started: $DBUS_SESSION_BUS_ADDRESS"
fi

# Start gnome-keyring-daemon (Must happen AFTER DBUS_SESSION_BUS_ADDRESS is set)
echo "Starting gnome-keyring-daemon..."
rm -f "$XDG_RUNTIME_DIR"/keyring/control # Clean up potentially stale control socket
KEYRING_CMD="/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh --daemonize"
echo "Executing keyring command: $KEYRING_CMD"
KEYRING_OUTPUT=$(eval "$KEYRING_CMD" 2>&1)
echo "Keyring daemon output: $KEYRING_OUTPUT"

export SSH_AUTH_SOCK
export GPG_AGENT_INFO
echo "SSH_AUTH_SOCK after keyring: $SSH_AUTH_SOCK"
echo "GPG_AGENT_INFO after keyring: $GPG_AGENT_INFO"

# Update the DBus activation environment
echo "Updating dbus activation environment..."
dbus-update-activation-environment --systemd --all || echo 'dbus-update-activation-environment failed or skipped.'

echo "--- Running graphical desktop commands ---"
xrdb -merge "$HOME/.config/X11/.Xresources"
urxvtd -o -q -f &
udiskie -A &

# --- FINAL STEP: Exec i3 with systemd session management ---
# This is the crucial part to make systemd-logind recognize the X11 session.
# We use dbus-run-session to wrap the *entire* X session.
# Note: If dbus-launch already ran above and set DBUS_SESSION_BUS_ADDRESS,
# this dbus-run-session might start a nested D-Bus, which is usually okay,
# but the primary goal is the logind integration.

echo "Attempting to launch i3 with logind session management..."
# Ensure systemd-run is installed
# sudo apt install systemd-container # (Might provide systemd-run)
# The 'loginctl enable-linger' for your user might also be needed if systemd --user isn't persistent.
# loginctl enable-linger $(whoami)

# Best approach for i3+systemd-logind is to wrap i3 startup in a way logind understands.
# This often involves starting it as a new session.

# Try using systemd-run with the appropriate slice and scope
# This tells systemd to manage this process.
#if command -v systemd-run >/dev/null 2>&1; then
#    exec systemd-run --user --scope \
#        -p "Delegate=yes" \
#        -p "Restart=on-failure" \
#        -p "RestartSec=5s" \
#        --unit="i3-wm.scope" \
#        --description="i3 Window Manager" \
#        --setenv=XDG_SESSION_TYPE=x11 \
#        --setenv=XDG_SESSION_DESKTOP=i3 \
#        i3
#else
#    # Fallback if systemd-run is not available or desired.
#    # This is where the old `exec i3` would go.
#    echo "systemd-run not found, falling back to direct exec i3."
#    exec i3
#fi
exec i3

# as of wiki.archlinux.org xinitrc
# mweitner however uncommented now because had not effect
#. /etc/X11/Xsession
