#!/bin/bash

# Define the window's matching criteria
WM_CLASS="Alacritty"
WM_TITLE="terminal_scratchpad"

# Check if the window is currently open (and thus in the scratchpad)
i3-msg "[class=\"$WM_CLASS\" title=\"$WM_TITLE\"] scratchpad show"

# Check the exit status of the previous command:
# If i3-msg successfully found and showed the window, the exit status is 0.
# If the window wasn't found (it was closed), the exit status will be non-zero (usually 1).
if [ $? -ne 0 ]; then
    # Window is closed, so launch a new one.
    alacritty --title terminal_scratchpad -e tmuxp load term-scratchpad -s term-sp
fi
