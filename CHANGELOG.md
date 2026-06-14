# Changelog

All notable changes to this personal dotfiles repository should be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and changes are grouped using a Semantic Versioning style when tagged releases are created.

## [Unreleased]

### Added (Unreleased)

- Placeholder for changes planned after the first tagged release.

### Changed (Unreleased)

- Placeholder for updates to existing setup scripts, configuration defaults, and docs.

### Fixed (Unreleased)

- Placeholder for bug fixes in automation, workstation setup, and validation tooling.

## [0.1.0] - 2026-06-14

### Added

- Fedora-first workstation bootstrap with `install-fedora.sh` for packages, symlinks, services,
    Docker setup, and shared Yocto directories.
- Development environment bootstrap with `install-fedora-dev.sh`, including VS Code installation,
    CLI tooling, pre-commit, MQTT tools, and Yocto host dependencies.
- Sway/Wayland-oriented desktop configuration for `sway`, `waybar`, `foot`, `mako`, `wofi`,
    `greetd`, and related user-environment tooling.
- Fish-shell-centered interactive workflow with helper functions, shell integration, and supporting
    Bash/Zsh compatibility files.
- Personal Sphinx documentation under `doc-engine/` with markdown-first source files and strict
    warning-as-error builds.
- Home-office VPN DNS repair workflow, including browser cache handling and troubleshooting docs.
- AI model selection tooling and hook integration under `tools/ai/` for cost-aware local workflow
    control.
- Repository validation via pre-commit, including markdownlint, ruff, shellcheck, yamlfmt,
    gitleaks, and JSON formatting hooks.

### Changed

- VS Code installation workflow updated to support newer pinned or latest-editor usage.
- Documentation build and markdown guidance tightened to require warning-free Sphinx output and
    labeled fenced code blocks.
- Root documentation expanded to describe installation flow, contribution expectations, and release
    tracking for this personal repository.

### Fixed

- Google keyring and related local setup friction reduced in the workstation bootstrap flow.
- Markdown formatting inconsistencies across docs cleaned up to satisfy strict linting.
- Shell and hook configuration issues resolved so the repository passes full pre-commit validation.

## Notes

- This is a personal repository, so formal releases are optional.
- Add versioned sections when a tag or other release milestone is intentionally created.
- Prefer entries that matter to future-you: setup behavior, validation rules, compatibility notes,
  and breaking configuration changes.

[0.1.0]: ../../releases/tag/v0.1.0
