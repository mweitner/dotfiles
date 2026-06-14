# Contributing Guide

This repository follows a repo-first workflow for personal workstation setup, automation, and
documentation.

## Scope

- System and user setup scripts live at repository root and under directories such as `shell/`,
  `systemd/`, `fish/`, `sway/`, `waybar/`, `tmux/`, and related config folders.
- Documentation sources live under `doc-engine/source/`.
- Repo docs are maintained at repository root, for example `README.md`,
  `INTEGRATION-VPN-DNS-FIX.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, and `.AI-GUIDELINES.md`.

## Contribution Flow

1. For small personal fixes, commit directly.
2. For larger refactors or risky machine-affecting changes, create a branch first.
3. Update scripts, configs, or docs according to the scope above.
4. Run validation locally:

   - `make -C doc-engine html`
   - `pre-commit run --all-files`

5. Test the changed workflow manually when installers, shell startup, networking, or system
   integration are affected.
6. Commit with a message that describes the user-visible effect.

## Release-Oriented Validation

Use a slightly stricter check before changes that should be part of a tagged release such as
`0.1.0`:

- Re-run the changed installer or helper script with the smallest safe scope.
- Confirm generated docs still build cleanly with `make -C doc-engine html`.
- Run `pre-commit run --all-files` from repo root.
- Check that any new docs mention the intended entry points from `README.md`.
- Summarize user-visible behavior changes in `CHANGELOG.md` under `Unreleased` until the release is
  tagged.

## Manual Verification Checklist

When a change affects workstation bootstrap, shell startup, or network tooling, verify the parts
you actually touched:

- Installer scripts: run the changed path on a test machine or with skip flags that exercise the
  modified logic.
- Shell config: start a fresh shell and confirm the command, alias, or function still loads.
- Sway/Waybar/desktop config: reload or restart the affected component and check for regressions.
- VPN or DNS helpers: verify both the repair command and a simple connectivity check still work.
- Secrets integration: confirm placeholders and copy paths are correct without committing private
  material.

## Personal Repo Considerations

- This is a personal repository, not a team-owned company project.
- Pull requests are optional; direct commits to `main` are acceptable when the change is understood
  and verified.
- Still prefer review discipline for sensitive edits: secrets handling, VPN/network changes,
  package repositories, boot/login setup, or anything that writes to system paths.

## Separation Rule

- Repo docs MAY reference content docs under `doc-engine/source/`.
- Content docs SHOULD avoid depending on repo-process docs unless the topic is specifically about
  this repository's tooling.
- Private material under `.secrets/` must never be documented with real credentials or committed.

See `.AI-GUIDELINES.md` for automation-specific editing and validation rules.

## Practical Guidance

- Keep changes small and easy to revert.
- Prefer idempotent installer logic.
- Document behavior changes that could surprise future-you on a fresh machine.
- When changing shell scripts, favor lint-clean updates and quote variables defensively.
