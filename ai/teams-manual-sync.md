# Teams Manual Sync Workflow

This workflow captures chat content from Teams Web with a bookmarklet and saves it into
`docs/ai-context` in your local repository.

## One-Time Setup

1. Open the bookmarklet source in [web-teams-bookmarklet.txt](web-teams-bookmarklet.txt).
2. Create a browser bookmark named `Teams Chat -> Markdown`.
3. Copy the full single-line bookmarklet JavaScript into the bookmark URL field.
4. Keep this save helper ready: [save-teams-chat-md.sh](save-teams-chat-md.sh).

## Daily Sync Steps

1. Open the target chat in Teams Web.
2. Scroll up until the required history is loaded.
3. Click your bookmarklet and then click `Copy` in the popup.
4. Save to your repository as a new daily file:

```bash
bash /home/ldcwem0/dotfiles/ai/save-teams-chat-md.sh \
  /home/ldcwem0/dps-dev \
  absprache-kommunikationsschnittstelle-lpo
```text
1. If you capture more chunks the same day, append to the same file:

```bash
bash /home/ldcwem0/dotfiles/ai/save-teams-chat-md.sh \
  /home/ldcwem0/dps-dev \
  absprache-kommunikationsschnittstelle-lpo \
  --append
```text
## Output Location

- Folder: `/home/ldcwem0/dps-dev/docs/ai-context`
- File name pattern: `teams-sync-YYYY-MM-DD-<topic>.md`

## Quick Checks

1. Verify file exists:

```bash
ls -lah /home/ldcwem0/dps-dev/docs/ai-context
```text
1. Preview first lines:

```bash
sed -n '1,40p' /home/ldcwem0/dps-dev/docs/ai-context/teams-sync-$(date +%Y-%m-%d)-absprache-kommunikationsschnittstelle-lpo.md
```text
