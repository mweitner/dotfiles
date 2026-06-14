#!/usr/bin/env python3
"""
Select an AI model for a given task using .ai-models.yaml selection_policies.

Usage:
  select_model.py --task complex_markdown_fix [--config .ai-models.yaml] [--auto-approve]

This helper reads the YAML config, chooses the first available model for the
task according to `selection_policies.task_priorities`, and prompts the user
if the selected model is marked as high-cost or if `prompt_on_select` is set.
"""

import sys
import argparse


def load_yaml(path):
    try:
        import yaml
    except Exception:
        print(
            "Missing dependency: PyYAML is required. Install with: pip install pyyaml",
            file=sys.stderr,
        )
        return None
    try:
        with open(path, "r") as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Config file not found: {path}", file=sys.stderr)
        return None


def pick_model(cfg, task):
    policies = cfg.get("selection_policies", {}).get("task_priorities", {})
    order = policies.get(task, [])
    models = cfg.get("models", {})
    # prefer first candidate present in models
    for m in order:
        if m in models:
            return m, models[m], order, "policy_match"
    # fallback: pick the first model in models
    for m, meta in models.items():
        return m, meta, order, "fallback_first_model"
    return None, None, order, "no_models"


def confirm_if_needed(model_name, meta, auto_approve, global_consent_policy):
    tier = meta.get("cost_tier", "medium")
    prompt_flag = meta.get("prompt_on_select", False)
    prompt_needed = prompt_flag or (
        global_consent_policy == "confirm_on_high" and tier == "high"
    )
    if auto_approve or not prompt_needed:
        return True
    # prompt user
    print(f"Selected model: {model_name} (cost_tier={tier})")
    ans = input("Proceed with this model? [y/N] ").strip().lower()
    return ans in ("y", "yes")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--config", default=".ai-models.yaml")
    p.add_argument("--task", required=True)
    p.add_argument(
        "--auto-approve", action="store_true", help="Do not prompt for high-cost models"
    )
    p.add_argument(
        "--explain",
        action="store_true",
        help="Print selection reasoning to stderr",
    )
    args = p.parse_args()

    cfg = load_yaml(args.config)
    if cfg is None:
        sys.exit(2)

    model, meta, order, reason = pick_model(cfg, args.task)
    if not model:
        print("No model found in config", file=sys.stderr)
        sys.exit(3)

    global_policy = cfg.get("consent", {}).get("policy", "confirm_on_high")
    if args.explain:
        available = ", ".join(cfg.get("models", {}).keys()) or "<none>"
        policy_order = ", ".join(order) if order else "<none>"
        print(f"[select_model] task={args.task}", file=sys.stderr)
        print(f"[select_model] policy_order={policy_order}", file=sys.stderr)
        print(f"[select_model] available_models={available}", file=sys.stderr)
        print(f"[select_model] reason={reason}", file=sys.stderr)
        print(f"[select_model] chosen_model={model}", file=sys.stderr)
        print(f"[select_model] consent_policy={global_policy}", file=sys.stderr)

    ok = confirm_if_needed(model, meta or {}, args.auto_approve, global_policy)
    if not ok:
        print("User cancelled selection.", file=sys.stderr)
        sys.exit(1)

    # Output chosen model name for downstream scripts
    print(model)
    return 0


if __name__ == "__main__":
    sys.exit(main())
