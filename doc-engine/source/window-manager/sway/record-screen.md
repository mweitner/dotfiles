# Record Screen

On Fedora with Sway, the most reliable way to capture browser playback or a local player is
`wf-recorder`. It is Wayland-native and works well for targeted recordings such as a VEO dashboard
video that cannot be downloaded directly.

## Install

```bash
sudo dnf install -y wf-recorder slurp ffmpeg libnotify
```

The base installer in this repository already includes `wf-recorder` and `slurp`.

## Sway Keybindings

```sh
# Screen recording - selected region / full output
bindsym $mod+Shift+v exec /home/ldcwem0/.config/sway/scripts/wf-record.sh region
bindsym $mod+Ctrl+Shift+v exec /home/ldcwem0/.config/sway/scripts/wf-record.sh full
# Screen recording with desktop audio
bindsym $mod+Mod1+Shift+v exec /home/ldcwem0/.config/sway/scripts/wf-record.sh region-audio
bindsym $mod+Mod1+Ctrl+v exec /home/ldcwem0/.config/sway/scripts/wf-record.sh full-audio
# Stop active screen recording
bindsym $mod+Mod1+v exec /home/ldcwem0/.config/sway/scripts/wf-record.sh stop
```

## Shell Workflow

Record a selected browser region without audio:

```bash
~/.config/sway/scripts/wf-record.sh region
```

Record the full focused output with desktop audio:

```bash
~/.config/sway/scripts/wf-record.sh full-audio
```

Stop the active recording:

```bash
~/.config/sway/scripts/wf-record.sh stop
```

Files are written to `~/videos/screencasts/` as `screencast_<mode>_<timestamp>.mp4`.

## VEO Dashboard Workflow

Use this when the original match or training video is only available for playback in the browser.

1. Open the VEO dashboard video in Chromium or Firefox.
2. Set the browser zoom and player size first.
3. Start `wf-record.sh region`.
4. Use `slurp` to draw a region around only the player area.
5. Start playback in the browser.
6. Stop the recording with `$mod+Mod1+v` or `wf-record.sh stop`.

Recording only the player region keeps the output file smaller and avoids leaking browser tabs,
notifications, or unrelated desktop content.

## Convert for Upload

If the raw recording is too large for a portal upload, compress it with `ffmpeg`:

```bash
ffmpeg -i raw.mp4 \
  -vf "scale=1280:-2" \
  -c:v libx264 -preset veryfast -crf 26 \
  -c:a aac -b:a 96k \
  upload.mp4
```

If audio is not needed, strip it to reduce size further:

```bash
ffmpeg -i raw.mp4 -an -c:v libx264 -preset veryfast -crf 24 upload-no-audio.mp4
```

## Notes

- `wf-recorder` records until stopped. There is no fixed duration unless you wrap it yourself.
- `region-audio` and `full-audio` depend on PipeWire or PulseAudio audio capture being available.
- Use screencasts only for internal or permitted sharing. Do not republish protected match footage.
