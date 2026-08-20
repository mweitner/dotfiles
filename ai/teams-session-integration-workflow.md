# Teams Session Integration Workflow (Local Capture)

This runbook covers Teams session capture when tenant APIs for recording/Copilot are not available.

## Scope

- local screen recording on Fedora + Sway
- local audio extraction independent from video recording
- transcript generation from extracted audio
- one merged meeting minutes output from multiple recording parts

## Inputs and Existing Helpers

- session manager script: `~/dotfiles/ai/ai-session-manager.sh` (recommended for organized sessions)
- recording script: `~/.config/sway/scripts/wf-record.sh`
- chat export helper: `~/dotfiles/ai/save-teams-chat-md.sh`
- bookmarklet source: `~/dotfiles/ai/web-teams-bookmarklet.txt`
- audio extraction helper: `~/dotfiles/ai/extract-session-audio.sh`
- transcript merge helper: `~/dotfiles/ai/merge-session-transcripts.sh`
- meeting skeleton helper: `~/dotfiles/ai/create-meeting-minutes-skeleton.sh`
- one-command wrapper: `~/dotfiles/ai/run-session-postprocess.sh`
- pre-call audio diagnostic: `~/dotfiles/ai/wf-record-audio-selftest.sh`

## Quick Start: AI Project + Session Workflow (Recommended)

The manager supports two context layers:

- active project: logical AI project root
- active session: sub-context inside the project (for example one Teams meeting)

Defaults when omitted:

- project: current month `yyyy.MM`
- session: current day `yyyy.MM.dd`

All outputs are stored under `~/.ai-sessions/<project-name>/<session-name>/`.

### Before Call

Initialize project with optional explicit session:

```bash
ai-session-prepare lpo-edge-interface-sync teams-sync-1
```

This creates `~/.ai-sessions/lpo-edge-interface-sync/teams-sync-1/` and activates both contexts.

Quick mode (no explicit project):

```bash
ai-session-prepare
```

This uses defaults, for example `~/.ai-sessions/2026.08/2026.08.14/`.

Optional script-native context activation (so later commands auto-target the active project/session):

```bash
ai-session-manager.sh project activate lpo-edge-interface-sync teams-sync-1
ai-session-manager.sh session activate teams-sync-2
# ... run commands without passing project/session repeatedly ...
ai-session-manager.sh project clear
```

### During Call

Start recording:

```bash
ai-screencast-start
```

In session break/segment transition:

```bash
ai-screencast-next  # Stops current recording, starts next immediately
# equivalent raw command: ai-session-manager.sh screencast next
```

### Check Status Anytime

```bash
ai-session-status   # Shows active project/session, mode, next part/files
```

### After Call: One-Command Post-Processing

```bash
PROJECT_NAME="lpo-edge-interface-sync"
SESSION_NAME="teams-sync-1"
SESSION_DIR="$HOME/.ai-sessions/$PROJECT_NAME/$SESSION_NAME"

bash ~/dotfiles/ai/run-session-postprocess.sh "$SESSION_DIR" "$PROJECT_NAME" ~/dps-dev \
  --chat-md "$SESSION_DIR/meeting-minutes.md" \
  --owner "Michael Weitner" --overwrite-audio --overwrite-merge --force-minutes
```

Result: All artifacts (video parts, audio, transcripts, markdown minutes) stay in one project folder.

## Pre-Call Audio Self-Test

Before important Teams sessions, verify monitor + mic capture quickly:

```bash
bash ~/dotfiles/ai/wf-record-audio-selftest.sh --duration 3
```

If needed, pin sources explicitly for the recording shell:

```bash
export WF_RECORD_AUDIO_DEVICE="<sink.monitor>"
export WF_RECORD_MIC_DEVICE="<mic.source>"
```

## One-Command Post-Processing

Run the full helper chain in one call:

```bash
bash ~/dotfiles/ai/run-session-postprocess.sh "$SESSION_DIR" "$SESSION_ID" ~/dps-dev \
  --chat-md ~/dps-dev/docs/ai-context/teams-sync-$(date +%Y-%m-%d)-$SESSION_ID.md \
  --owner "TBD" --overwrite-audio --overwrite-merge --force-minutes
```

This wrapper executes:

1. `extract-session-audio.sh`
2. `merge-session-transcripts.sh`
3. `create-meeting-minutes-skeleton.sh`

## Known Drawback and Workaround

Drawback:

- desktop monitor capture can miss your own headset microphone, so only remote participants are
  heard in the recording.

Workaround:

1. Preferred: route remote audio + mic into one combined PipeWire source and use it as
   `WF_RECORD_AUDIO_DEVICE`.
2. Fallback: keep `wf-record.sh` for screen + remote audio and record mic as a second track, then
   merge in post-processing.
3. Current integration: `wf-record.sh` enhanced with parallel mic capture; sessions via
   `ai-session-manager.sh` handle part organization automatically.

## Advanced: Manual Workflow (Alternative to Session Manager)

For ad-hoc single recordings or when session manager is not available, manage folders manually:

```bash
SESSION_ID="teams-2026-08-13-lpo-edge-interface"
SESSION_DIR="$HOME/videos/screencasts/$SESSION_ID"
mkdir -p "$SESSION_DIR"
```

Store all parts in that folder.

## Step 1: Record Session Parts

Use your existing Sway keybindings or shell commands:

```bash
~/.config/sway/scripts/wf-record.sh full-audio
~/.config/sway/scripts/wf-record.sh stop
```

Repeat for each meeting segment. Rename or move parts into `SESSION_DIR` with ordered part
numbers.

## Step 2: Extract Audio Per Part (Independent from Recording)

Preferred command:

```bash
bash ~/dotfiles/ai/extract-session-audio.sh "$SESSION_DIR" --format wav --sample-rate 16000 \
  --channels 1 --pattern '*part*.mp4'
```

Equivalent manual loop:

```bash
for f in "$SESSION_DIR"/*.mp4; do
  ffmpeg -i "$f" -vn -ac 1 -ar 16000 "${f%.mp4}.wav"
done
```

This can be executed later and does not block recording flow.

## Step 3: Optional Mic Track Merge (Fallback Mode)

If you recorded your mic separately, merge remote + mic into one transcript input first.

Example shape:

```bash
ffmpeg -i part01-remote.wav -i part01-mic.wav \
  -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0" \
  -ac 1 -ar 16000 part01-mix.wav
```

## Step 4: Transcribe Each Part

### Option A: Local whisper.cpp (automated, offline)

**Prerequisite:** see [ASR Setup: whisper.cpp with GPU acceleration](#asr-setup-whispercpp-with-gpu-acceleration) below.

```bash
for f in "$SESSION_DIR"/*.wav; do
  whisper-cli -m "$HOME/models/ggml-large-v3.bin" -f "$f" -of "${f%.wav}"
done
```

### Option B: Gemini web prompt (manual, no setup required)

Use this until whisper.cpp is installed. Steps:

1. Open [aistudio.google.com](https://aistudio.google.com) or Gemini Advanced.
2. Attach the `.wav` file(s) from the session folder directly.
3. Prompt:

```text
This is a recorded meeting audio file.
Please generate a clean text transcript of the full content.
Preserve speaker turns if identifiable.
Language may be German and/or English mixed.
```

4. Save the raw transcript output as:
   `<session-dir>/<session-id>-part-NN.txt` (one file per uploaded wav).
5. Continue with Step 5 (merge) using these files as input.

> Audio files for backlog sessions (already extracted, ready to upload):
>
> - `~/ems-dev/organization/meeting-minutes/2026.07.22-ems-reisenbauer/screencast_region_20260722_160220.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_095647.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_103027.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_104842.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_105300.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_110244.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_110812.wav`

## Step 5: Merge Raw Transcript Parts

Preferred command:

```bash
bash ~/dotfiles/ai/merge-session-transcripts.sh "$SESSION_DIR" "$SESSION_ID" \
  --pattern '*part*.txt' --overwrite
```

Equivalent manual command:

```bash
cat "$SESSION_DIR"/*part*.txt > "$SESSION_DIR/$SESSION_ID-merged-transcript.txt"
```

## Step 6: Capture Teams Chat Text (Manual Bookmarklet)

Use Teams web bookmarklet copy and save:

```bash
bash ~/dotfiles/ai/save-teams-chat-md.sh ~/dps-dev "$SESSION_ID" --append
```

This gives text context that often includes names, links, and written decisions.

## Step 7: Generate One Meeting Minutes Markdown

Create a minutes skeleton first:

```bash
bash ~/dotfiles/ai/create-meeting-minutes-skeleton.sh ~/dps-dev "$SESSION_ID" \
  --transcript "$SESSION_DIR/$SESSION_ID-merged-transcript.txt"
```

Prompt your AI assistant with:

- merged transcript text
- Teams chat markdown export
- project context links

Prompt template:

```text
Generate technical meeting minutes from the provided transcript and Teams chat markdown.

Requirements:
- Merge duplicated statements across parts.
- Keep decisions, constraints, open questions, and action items.
- Include owners and due dates when available.
- Mark unclear points explicitly.

Output sections:
1. Session Metadata
2. Decisions
3. Requirement / Architecture Impact
4. Action Items
5. Open Questions
6. Sources
```

## Recommended Output Paths

**With Session Manager (Recommended):**

- all session artifacts (video, audio, transcripts, markdown):
  - `$HOME/.ai-sessions/<session-id>/`

**Manual Workflow (Alternative):**

- raw media and transcript artifacts:
  - `$HOME/videos/screencasts/$SESSION_ID/`
- final minutes for engineering workflow:
  - `<repo>/docs/ai-context/teams-mm-$SESSION_ID.md`

## Validation Checklist

- confirm all `mp4` parts were processed into `wav`
- confirm transcript exists for each part
- confirm merged transcript contains your own spoken contributions
- confirm final markdown minutes include owners and action items

---

## ASR Setup: whisper.cpp with GPU acceleration

### Hardware status (as of 2026-08-19)

| Component | Status | Notes |
|---|---|---|
| GPU | NVIDIA RTX PRO 2000 Blackwell (GB206GLM) | Laptop, physically present |
| Proprietary NVIDIA driver | **not installed** | Required for CUDA and NVIDIA Vulkan |
| CUDA runtime | **not available** | Blocked by missing driver |
| NVIDIA Vulkan | **not available** | Blocked by missing driver |
| Intel iGPU Vulkan | available | `libvulkan_intel.so` present via Mesa |
| Nouveau Vulkan | available | open-source, compute not practical |

**Current state:** CPU-only ASR execution or Intel iGPU Vulkan fallback only.
**Target state:** CUDA-accelerated NVIDIA RTX (30–50x faster than CPU-only).

### Expected performance once NVIDIA driver is installed

| Model | CPU-only | RTX 2000 (CUDA) |
|---|---|---|
| `large-v3` | ~0.2x realtime (~160 min for 33 min recording) | ~15–20x realtime (~2 min) |
| `medium` | ~0.5x realtime | ~40x realtime |
| `small` | ~2x realtime | fast |

### TODO: whisper.cpp setup (tracked here until moved to install script)

Priority 1: Install NVIDIA proprietary driver (required for CUDA)

```bash
# Fedora: install via RPM Fusion
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda
# reboot and verify:
nvidia-smi
```

> BIOS note: on some Lenovo/ASUS laptops, the dGPU may be disabled via
> "Hybrid Mode" in BIOS. Verify it is enabled or set to "Discrete GPU" if
> you want always-on CUDA availability.

Priority 2: Build and install whisper.cpp with CUDA support

```bash
git clone https://github.com/ggerganov/whisper.cpp ~/tools/whisper.cpp
cd ~/tools/whisper.cpp
# CUDA build:
make GGML_CUDA=1
# install binary into PATH:
sudo cp build/bin/whisper-cli /usr/local/bin/whisper-cli
# download model (large-v3, ~3 GB):
bash models/download-ggml-model.sh large-v3
mkdir -p ~/models
cp models/ggml-large-v3.bin ~/models/
```

Priority 3: Validate end-to-end pipeline

```bash
# quick smoke test with a short wav:
whisper-cli -m ~/models/ggml-large-v3.bin -f <some-test.wav> -of /tmp/test-out
cat /tmp/test-out.txt
```

Priority 4: Add whisper-cli to install-fedora.sh

Add a section under `# AI tooling` in `~/dotfiles/install-fedora.sh`:

```bash
# whisper.cpp - local ASR for meeting transcript generation
# Build: see ~/dotfiles/ai/teams-session-integration-workflow.md
# Requires: NVIDIA driver + CUDA (akmod-nvidia xorg-x11-drv-nvidia-cuda)
```

### Vulkan fallback path (Intel iGPU, no NVIDIA driver required)

If you want to use whisper.cpp before the NVIDIA driver is set up, the Intel
iGPU Vulkan path is available today. Performance is roughly 2–5x CPU speed
(not as fast as RTX but workable for short recordings):

```bash
# Vulkan build (uses available Intel iGPU Vulkan via Mesa):
make GGML_VULKAN=1
```

This is a useful interim option for short sessions (\<15 min) while waiting
for the NVIDIA driver setup window.
