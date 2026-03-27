# Pre-commit SSL Certificate Verification Issue

## Problem

While running pre-commit hooks, you may see errors like:

```text
URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED]
certificate verify failed: Missing Authority Key Identifier (_ssl.c:1081)>
```

This happens when pre-commit tries to bootstrap runtime binaries via Python tooling, for example:

- Go runtime from `https://go.dev`
- Node runtime from `https://nodejs.org` (via `nodeenv`)

## Root Cause (Observed)

On some systems using Python 3.14, pre-commit runtime bootstrapping via Python urllib can fail SSL verification for selected endpoints.

- curl can reach the same endpoints successfully
- GitHub access may work in parallel
- Python urllib-based runtime download can fail in `nodeenv` or go bootstrap

In tested cases this behaves like a Python SSL/runtime-download path issue, not a general network outage.

## Recommended Fix

Use system runtimes for Node and Go in the affected repository:

1. Set `.pre-commit-config.yaml` language versions to `system` for `node` and `golang`
2. Install pre-commit hook scripts
3. Pre-cache hook environments with `pre-commit run --all-files`

The helper scripts in dotfiles automate this.

## Examples

### Example 1: First-time setup in a failing repo

```bash
cd ~/dps-dev/docs/ad-cot-fieldtest
setup-pre-commit
```

What this does:

1. Patches `node` and `golang` language versions to `system`
2. Runs `pre-commit install`
3. Runs `pre-commit run --all-files`

### Example 2: Quick patch + retry using helper

```bash
cd ~/dps-dev/docs/ad-cot-fieldtest
pre-commit-helper --fix-config
pre-commit-helper --install
pre-commit-helper --run
```

### Example 3: Commit amend with fallback

```bash
cd ~/dps-dev/docs/ad-cot-fieldtest
pre-commit-helper --amend-no-edit
```

This tries:

1. `git commit --amend --no-edit`
2. On hook failure: `git commit --amend --no-edit --no-verify`

### Example 4: One-off emergency bypass

```bash
git commit --amend --no-edit --no-verify
pre-commit-helper --run
```

Use this only when you need to unblock immediately.

## Commands Cheat Sheet

```bash
setup-pre-commit
pre-commit-helper --fix-config
pre-commit-helper --install
pre-commit-helper --run
pre-commit-helper --commit "message"
pre-commit-helper --amend-no-edit
```

## References

- [Python 3.14 SSL module](https://docs.python.org/3.14/library/ssl.html)
- [Pre-commit documentation](https://pre-commit.com/)
- [nodeenv](https://github.com/ekalinin/nodeenv)
