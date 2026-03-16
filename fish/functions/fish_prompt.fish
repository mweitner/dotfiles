function fish_prompt
    set -l last_status $status
    set -l short_cwd (prompt_pwd --dir-length 1)

    # Tiny mode marker near cursor: N=normal, I=insert, R=replace, V=visual.
    set -l mode_marker I
    set -l mode_color green
    switch $fish_bind_mode
        case default
            set mode_marker N
            set mode_color yellow
        case insert
            set mode_marker I
            set mode_color green
        case replace_one replace
            set mode_marker R
            set mode_color red
        case visual
            set mode_marker V
            set mode_color magenta
    end

    set_color brblack
    echo -n "$short_cwd"

    if test $last_status -ne 0
        set_color red
        echo -n " [$last_status]"
    end

    set_color normal
    echo -n " "
    set_color $mode_color
    echo -n "$mode_marker"
    set_color cyan
    echo -n "> "
    set_color normal
end
