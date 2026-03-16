# Take Screenshot

On Wayland and Sway, `scrot` does not work because it relies on X11 protocols. The industry-standard replacement for
Sway is a combination of two tools:


1. `**grim**`: The tool that actually grabs the image (the "camera").
2. `**slurp**`: The tool that lets you select a region with your mouse (the "viewfinder").

## Install

```bash
sudo dnf install -y grim slurp wl-clipboard libnotify
```

## Configure Sway

```sh
# Screenshots
bindsym Print exec ~/.config/sway/scripts/grimshot.sh full
bindsym $mod+Print exec ~/.config/sway/scripts/grimshot.sh region
```

**Note:** This setup is much more powerful than scrot because it leverages wl-copy, allowing you to immediately paste
your screenshots into Chromium, Slack, or Jira without even opening the file manager.
