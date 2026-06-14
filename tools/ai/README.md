Select Model Helper
===================

Purpose
-------

`select_model.py` is a small CLI helper that selects an AI model for a named
task using the repository `.ai-models.yaml` `selection_policies` and prompts the
user before choosing a high-cost model. This file documents usage and shows how
to integrate the helper into simple git hooks or automation.

Requirements
------------

- Python 3.8+
- PyYAML (`pip install pyyaml`)

Usage
-----

Run the helper to pick a model for a given task. It prints the chosen model
name to stdout and exits non-zero if the user cancels a prompt:

```bash
python3 tools/ai/select_model.py --task complex_markdown_fix
```

To understand how the decision was made, use `--explain`:

```bash
python3 tools/ai/select_model.py --task complex_markdown_fix --explain
```

Options
-------

- `--config`: path to YAML config (default: `.ai-models.yaml`)
- `--task`: (required) task name as found under `selection_policies.task_priorities`
- `--auto-approve`: skip interactive prompts (useful for CI)
- `--explain`: print policy order, available models, and selection reason

Example integration in scripts
------------------------------

Call the helper from a shell script and capture the chosen model:

```bash
MODEL=$(python3 tools/ai/select_model.py --task complex_markdown_fix)
if [ $? -ne 0 ]; then
  echo "Model selection cancelled; aborting."
  exit 1
fi

echo "Selected model: $MODEL"
# pass $MODEL to the agent runner or use as part of the request
```

Git hook example
----------------

Preferred: combine with `.pre-commit-config.yaml`

This repository already uses `pre-commit` with hooks from
`.pre-commit-config.yaml`. The recommended setup is to run the AI selector as a
local pre-commit hook inside that pipeline (configured as `ai-model-select`).

Install or refresh the standard pre-commit git hook:

```bash
pre-commit install
```

Now `git commit` runs the AI selector and then the regular pre-commit hooks.

You can run only the AI hook manually:

```bash
pre-commit run ai-model-select --all-files
```

Alternative: standalone `.git/hooks/pre-commit` replacement

Place the example hook script `tools/ai/hooks/pre-ai-model-select.sh` into
`.git/hooks/pre-commit` (or symlink it), and make it executable:

```bash
cp tools/ai/hooks/pre-ai-model-select.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Why this pre-commit hook helps
------------------------------

The hook is a lightweight "human-in-the-loop" gate before each commit:

- it selects a model for the configured task using `selection_policies`
- it can prompt before high-cost model selection (when policy says so)
- it can stop the commit if you reject the selection

This is useful while learning AI-assisted workflows because decisions become
visible and explicit at commit time instead of being hidden in tooling.

Important:

- if the chosen model is not marked high-cost, no prompt appears
- in your current config, `complex_markdown_fix` resolves to `gpt-5-mini`, so
  the hook prints the selected model and continues without asking

Hook installer (recommended)
----------------------------

The installer below is for standalone replacement mode where AI hook directly
occupies `.git/hooks/pre-commit`. For combined mode, use `pre-commit install`.

Use the installer script to safely install or remove the hook:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --status
tools/ai/hooks/install-pre-ai-hook.sh --install
tools/ai/hooks/install-pre-ai-hook.sh --status
```

The installer backs up an existing `.git/hooks/pre-commit` before replacing it.

To uninstall:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --uninstall
```

To uninstall and restore your latest backup in one step:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --uninstall-restore
```

Manual walkthrough (learn-by-doing)
-----------------------------------

1. See current policy behavior:

```bash
python3 tools/ai/select_model.py --task complex_markdown_fix --explain
```

2. Test non-interactive mode (CI-like):

```bash
python3 tools/ai/select_model.py --task complex_markdown_fix --auto-approve --explain
```

3. Install hook and trigger it with a commit:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --install
git commit --allow-empty -m "test: ai hook"
```

4. If hook prompt appears and you answer `n`, commit stops (expected).

5. If needed, remove hook again:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --uninstall
```

6. To restore your previous pre-commit hook automatically:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --uninstall-restore
```

If `--uninstall` says "nothing to remove" even after install, run:

```bash
tools/ai/hooks/install-pre-ai-hook.sh --status
```

This usually means the hook file was modified or replaced by another tool.
The installer now detects installed AI hooks by content match and known marker
lines, so this should be rare.

If `--uninstall-restore` reports no backup found, you likely installed the AI
hook when there was no existing pre-commit hook to back up.

Tip: to force prompt behavior for demo purposes, set `cost_tier: high` for the
selected model and add:

```yaml
consent:
  policy: confirm_on_high
```

CI / automation
---------------

In CI you can use `--auto-approve` so the helper does not prompt:

```bash
MODEL=$(python3 tools/ai/select_model.py --task complex_markdown_fix --auto-approve)
```

Security & Audit
----------------

- The helper is intentionally conservative: it prompts before selecting
  models with `cost_tier: high` (or `prompt_on_select: true`).
- When you consent to a high-cost model, consider adding a commit tag like:

  `[AI-ASSISTED][model:claude_opus_4_6][consent:yes]`

Support
-------

If you want me to wire this into your local agent/runner, share the path to
the runner script and I can add a small integration shim.
