# Teams Session Integration Workflow (Local Capture)

This runbook covers Teams session capture when tenant APIs for recording or Copilot are not available.

## Scope

- local screen recording on Fedora + Sway
- local audio extraction independent from video recording
- transcript generation from extracted audio
- one merged meeting minutes output from multiple recording parts
- moderator-friendly capture of headset audio plus participant audio
- a single canonical markdown minutes prompt for live deep-dive sessions

## Inputs and existing helpers

- session manager script: `~/dotfiles/ai/ai-session-manager.sh` (recommended for organized sessions)
- recording script: `~/.config/sway/scripts/wf-record.sh`
- chat export helper: `~/dotfiles/ai/save-teams-chat-md.sh`
- bookmarklet source: `~/dotfiles/ai/web-teams-bookmarklet.txt`
- audio extraction helper: `~/dotfiles/ai/extract-session-audio.sh`
- transcript merge helper: `~/dotfiles/ai/merge-session-transcripts.sh`
- meeting skeleton helper: `~/dotfiles/ai/create-meeting-minutes-skeleton.sh`
- one-command wrapper: `~/dotfiles/ai/run-session-postprocess.sh`
- pre-call audio diagnostic: `~/dotfiles/ai/wf-record-audio-selftest.sh`
- canonical minutes prompt: `~/dotfiles/ai/teams-session-meeting-minutes-prompt.md`

## Moderator protocol for live deep-dive sessions

Use this flow when you are moderating a live technical deep dive and cannot take notes manually.

1. Prepare the active project and session before the call so every artifact lands in one folder.
2. Run the audio self-test and confirm both your headset mic and participant audio are audible.
3. Start the screencast and record as many parts as needed during the session.
4. Keep per-part audio extraction and transcript generation separate from the live call.
5. Merge the transcript parts after the session and then generate one markdown minutes file from the canonical prompt.
6. Preserve moderator remarks, decisions, and unresolved items explicitly instead of trying to reconstruct them later.

## Quick start: AI project + session workflow (recommended)

The manager supports two context layers:

- active project: logical AI project root
- active session: sub-context inside the project (for example one Teams meeting)

Defaults when omitted:

- project: current month `yyyy.MM`
- session: current day `yyyy.MM.dd`

All outputs are stored under `~/.ai-sessions/<project-name>/<session-name>/`.

### Before the call

Initialize a project with an explicit session:

```bash
~/dotfiles/ai/ai-session-manager.sh prepare lpo-edge-interface-sync teams-sync-1
```

This creates `~/.ai-sessions/lpo-edge-interface-sync/teams-sync-1/` and activates both contexts.

Quick mode (no explicit project):

```bash
~/dotfiles/ai/ai-session-manager.sh prepare
```

This uses defaults such as `~/.ai-sessions/2026.08/2026.08.14/`.

Optional script-native context activation:

```bash
~/dotfiles/ai/ai-session-manager.sh project activate lpo-edge-interface-sync teams-sync-1
~/dotfiles/ai/ai-session-manager.sh session activate teams-sync-2
# ... run commands without passing project/session repeatedly ...
~/dotfiles/ai/ai-session-manager.sh project clear
```

### During the call

Start recording:

```bash
~/dotfiles/ai/ai-session-manager.sh screencast start
```

During a break or segment transition:

```bash
~/dotfiles/ai/ai-session-manager.sh screencast next
```

### Check status anytime

```bash
~/dotfiles/ai/ai-session-manager.sh status
```

### After the call: one-command post-processing

```bash
PROJECT_NAME="lpo-edge-interface-sync"
SESSION_NAME="teams-sync-1"
SESSION_DIR="$HOME/.ai-sessions/$PROJECT_NAME/$SESSION_NAME"

bash ~/dotfiles/ai/run-session-postprocess.sh "$SESSION_DIR" "$PROJECT_NAME" ~/dps-dev \
  --chat-md "$SESSION_DIR/meeting-minutes.md" \
  --owner "Michael Weitner" --overwrite-audio --overwrite-merge --force-minutes
```

Result: all artifacts (video parts, audio, transcripts, markdown minutes) stay in one project folder.

## Pre-call audio self-test

Before important Teams sessions, verify monitor + mic capture quickly:

```bash
bash ~/dotfiles/ai/wf-record-audio-selftest.sh --duration 3
```

If needed, pin sources explicitly for the recording shell:

```bash
export WF_RECORD_AUDIO_DEVICE="<sink.monitor>"
export WF_RECORD_MIC_DEVICE="<mic.source>"
```

## One-command post-processing

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

## Known drawback and workaround

Drawback:

- desktop monitor capture can miss your own headset microphone, so only remote participants are heard in the recording.

Workaround:

1. Preferred: route remote audio and mic into one combined PipeWire source and use it as `WF_RECORD_AUDIO_DEVICE`.
2. Fallback: keep `wf-record.sh` for screen + remote audio and record the mic as a second track, then merge it in
 post-processing.
3. Current integration: `wf-record.sh` supports parallel mic capture; sessions via `ai-session-manager.sh` handle part
 organization automatically.

## Advanced: manual workflow (alternative to the session manager)

For ad-hoc single recordings or when the session manager is not available, manage folders manually:

```bash
SESSION_ID="teams-2026-08-13-lpo-edge-interface"
SESSION_DIR="$HOME/videos/screencasts/$SESSION_ID"
mkdir -p "$SESSION_DIR"
```

Store all parts in that folder.

## Step 1: record session parts

Use your existing Sway keybindings or shell commands:

```bash
~/.config/sway/scripts/wf-record.sh full-audio
~/.config/sway/scripts/wf-record.sh stop
```

Repeat for each meeting segment. Rename or move parts into `SESSION_DIR` with ordered part numbers.

## Step 2: extract audio per part (independent from recording)

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

This can be executed later and does not block the recording flow.

## Step 3: optional mic-track merge (fallback mode)

If you recorded the mic separately, merge remote audio and mic audio into one transcript input first.

Example shape:

```bash
ffmpeg -i part01-remote.wav -i part01-mic.wav \
  -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0" \
  -ac 1 -ar 16000 part01-mix.wav
```

## Step 4: transcribe each part

### Option A: local whisper.cpp (default automated mode, offline)

**Prerequisite:** see [ASR Setup: whisper.cpp with GPU acceleration](#asr-setup-whispercpp-with-gpu-acceleration)
below.

```bash
for f in "$SESSION_DIR"/*.wav; do
  whisper-cli -m "$HOME/models/ggml-large-v3.bin" -f "$f" -of "${f%.wav}" -osrt
done
```

The manager converts the SRT output into the timestamped text format used during minutes refinement:

```text
[hh:mm:ss][speaker-unknown] text
```

For the verified full-flow diarization run, use the wrapper script with the default runtime settings:

```bash
bash ~/dotfiles/ai/run-ai-session-minutes.sh les-ems-pilot-ecocoach 2026.08.27-technical-deep-dive
```

Equivalent direct environment flow:

```bash
export HF_TOKEN="$(cat /home/ldcwem0/dotfiles/.secrets/hf/.hf-les-ems-whisperx-diarization-local-2026-08)"
export HUGGINGFACE_TOKEN="$HF_TOKEN"
export AI_PROJECT=les-ems-pilot-ecocoach
export AI_SESSION=2026.08.27-technical-deep-dive
export AI_ASR_MODEL="/home/ldcwem0/tools/whisper.cpp/models/ggml-large-v3.bin"
export AI_WHISPERX_BIN="/home/ldcwem0/.local/bin/whisperx"
export AI_ASR_DEVICE=cpu
export AI_ASR_BATCH_SIZE=1
bash ~/dotfiles/ai/ai-session-manager.sh create-minutes --title "LES EMS Ecocoach technical deep dive" --owner TBD --date 2026-08-27 --diarize --overwrite
```

Best-practice flow for stable speaker aliases:

1. Before the first run, edit the roster file in the session folder:
   `<project>-<session>-speaker-roster.tsv`
2. Run diarization once (`--diarize`) to detect speakers and create:
   - `<project>-<session>-speaker-map.tsv`
   - `<project>-<session>-speaker-stats.md`
3. Map detected speakers (for example `speaker00`) to aliases such as `short-unique-name1` and `short-unique-name2` in
 the speaker-map file.
4. Rerun `update-minutes --diarize` to re-apply alias mapping and refresh the merged transcript and minutes draft.

Roster format example:

```text
# alias<TAB>display_name<TAB>role
short-unique-name1\tfull-name1\tname1-context1, name1-context2
short-unique-name2\tfull-name2\tname2-context1, name2-context2
```

In diarization mode, transcript lines are normalized to:

```text
[hh:mm:ss][speaker-a] spoken text
```

### Option B: manual fallback (Gemini/ChatGPT/other)

Use this only when ASR tooling is unavailable.

1. Open [aistudio.google.com](https://aistudio.google.com) or Gemini Advanced.
2. Attach the `.wav` file(s) from the session folder directly.
3. Prompt:

```text
This is a recorded meeting audio file.
Please generate a clean text transcript of the full content.
Preserve speaker turns if identifiable.
Language may be German and/or English mixed.
```

4. Save the raw transcript output as `<session-dir>/<session-id>-part-NN.txt` (one file per uploaded wav).
5. Continue with the merge step using these files as input.

> Audio files for backlog sessions (already extracted, ready to upload):
>
> - `~/ems-dev/organization/meeting-minutes/2026.07.22-ems-reisenbauer/screencast_region_20260722_160220.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_095647.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_103027.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_104842.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_105300.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_110244.wav`
> - `~/ems-dev/organization/meeting-minutes/2026.08.05-ems-reisenbauer/screencast_region_20260805_110812.wav`

## Step 5: merge raw transcript parts

Preferred command:

```bash
bash ~/dotfiles/ai/merge-session-transcripts.sh "$SESSION_DIR" "$SESSION_ID" \
  --pattern '*part*.txt' --overwrite
```

Equivalent manual command:

```bash
cat "$SESSION_DIR"/*part*.txt > "$SESSION_DIR/$SESSION_ID-merged-transcript.txt"
```

## Step 6: capture Teams chat text (manual bookmarklet)

Use the Teams web bookmarklet to copy and save chat content:

```bash
bash ~/dotfiles/ai/save-teams-chat-md.sh ~/dps-dev "$SESSION_ID" --append
```

This gives textual context that often includes names, links, and written decisions.

## Step 7: generate one meeting minutes markdown

Create a minutes skeleton first:

```bash
bash ~/dotfiles/ai/create-meeting-minutes-skeleton.sh ~/dps-dev "$SESSION_ID" \
  --transcript "$SESSION_DIR/$SESSION_ID-merged-transcript.txt"
```

Prompt your AI assistant with:

- merged transcript text
- Teams chat markdown export
- project context links

Canonical prompt file:

- `~/dotfiles/ai/teams-session-meeting-minutes-prompt.md`

Use the prompt file as the baseline when the session includes multiple video parts, multiple audio sources, or a
moderated speaker flow where your own headset audio must be captured alongside participant audio.

Prompt template:

```text
Generate technical meeting minutes from the provided transcript and Teams chat markdown.

Requirements:
- Merge duplicated statements across parts.
- Keep decisions, constraints, open questions, and action items.
- Include owners and due dates when available.
- Preserve moderator remarks when they affect decisions or scope.
- Mark uncertain speaker attribution as unclear instead of guessing.
- Note gaps in headset or participant audio when they affect interpretation.
- Mark unclear points explicitly.

Output sections:
1. Session Metadata
2. Recording and Audio Inventory
3. Decisions
4. Requirement / Architecture Impact
5. Action Items
6. Open Questions
7. Risks and Assumptions
8. Sources
```

## Recommended output paths

**With the session manager (recommended):**

- all session artifacts (video, audio, transcripts, markdown):
  - `$HOME/.ai-sessions/<session-id>/`

**Manual workflow (alternative):**

- raw media and transcript artifacts:
  - `$HOME/videos/screencasts/$SESSION_ID/`
- final minutes for the engineering workflow:
  - `<repo>/docs/ai-context/teams-mm-$SESSION_ID.md`

## Validation checklist

- confirm all `mp4` parts were processed into `wav`
- confirm a transcript exists for each part
- confirm participant audio is present in the capture chain
- confirm the merged transcript includes your own spoken contributions
- confirm the final markdown minutes include owners and action items

---

## ASR setup: whisper.cpp with GPU acceleration

### Hardware status (as of 2026-08-19)

| Component | Status | Notes |
|---|---|---|
| GPU | NVIDIA RTX PRO 2000 Blackwell (GB206GLM) | Laptop, physically present |
| Proprietary NVIDIA driver | **not installed** | Required for CUDA and NVIDIA Vulkan |
| CUDA runtime | **not available** | Blocked by missing driver |
| NVIDIA Vulkan | **not available** | Blocked by missing driver |
| Intel iGPU Vulkan | available | `libvulkan_intel.so` present via Mesa |
| Nouveau Vulkan | available | open-source; compute is not practical |

**Current state:** CPU-only ASR execution or Intel iGPU Vulkan fallback only.
**Target state:** CUDA-accelerated NVIDIA RTX (30–50x faster than CPU-only).

### Expected performance once the NVIDIA driver is installed

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

Priority 4: Add whisper-cli to install-fedora-dev.sh

Add a section under `# AI tooling` in `~/dotfiles/install-fedora-dev.sh`:

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
