function nmtui --description 'Open nmtui in Sway scratchpad window'
    if test -x "$HOME/.local/bin/nmtui"
        "$HOME/.local/bin/nmtui" $argv
        return $status
    end

    if set -q SWAYSOCK; and test -S "$SWAYSOCK"; and command -q swaymsg; and swaymsg -t get_version >/dev/null 2>&1
        if test -x "$HOME/.config/sway/scripts/toggle-scratchpad-nmtui.sh"
            "$HOME/.config/sway/scripts/toggle-scratchpad-nmtui.sh"; and return 0
        end
    end

    command nmtui $argv
end
