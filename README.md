# LAIDBACK HOME

**Laidback Home Environment** — A mise-first, XDG-compliant home control plane for deterministic
human and AI/script shell orchestration.

![CI Status](https://github.com/laidback/laidback-dotfiles/actions/workflows/ci.yml/badge.svg)
![Mise First](https://img.shields.io/badge/mise-first-brightgreen)
![XDG](https://img.shields.io/badge/xdg-compliant-blue)

## Overview

`LAIDBACK HOME` is the home-level control plane for shell behavior, environment defaults, secrets
posture, and toolchain lifecycle. It is designed for full shell control across interactive user
sessions and AI/script execution sessions while keeping XDG-compliant runtime locations.

After bootstrap, global `dotfiles:*` tasks are available system-wide via mise. Repository tasks
for development and release are available from the cloned project directory.

## Key Features

- **Shell Control**: Distinct behavior for interactive human usage and AI/script usage.
- **Environment Control**: Centralized defaults in `home/.config/shell/env.sh` with explicit LAIDBACK/XDG variables.
- **XDG Compliance**: Home state follows XDG paths for config/data/state/cache/runtime.
- **Secrets Ready**: `sops` + `age` checks integrated into management tasks.
- **Mise First**: One root `mise.toml` controls repository-local tasks/tools; home config supports
  global use via `MISE_TASKS_DIR`.
- **Global Tasks**: `dotfiles:status`, `dotfiles:doctor` available anywhere after bootstrap.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/laidback/laidback-dotfiles/main/install.sh | bash
```

The installer:

1. Detects your OS and architecture.
2. Installs `mise` if not present.
3. Installs `git` if not present.
4. Clones the repository to `$XDG_PROJECTS_DIR/github.com/laidback/laidback-dotfiles`.
5. Runs `mise run bootstrap` to configure your home environment.

After bootstrap, restart your shell. Global tasks are then available from anywhere:

```bash
mise run dotfiles:status
mise run dotfiles:doctor
```

## Architecture

See `ARCHITECTURE.md` for full variable and topology details.

Highlights:

- Full user `$HOME` XDG setup for LAIDBACK and mise locations.
- Shell/editor/pager defaults for interactive and automation modes.
- `MISE_TASKS_DIR` points to `~/.config/laidback/mise/tasks/` for global namespaced tasks.
- Secrets management gates using `sops` and `age`.

## Global vs Repository Tasks

| Context | Command | Notes |
|---------|---------|-------|
| Anywhere | `mise run dotfiles:status` | Requires bootstrap completed |
| Anywhere | `mise run dotfiles:doctor` | Requires bootstrap completed |
| Repository | `mise run status` | Direct task from `mise.toml` |
| Repository | `mise run doctor` | Direct task from `mise.toml` |
| Repository | `mise run validate` | Full validation gate |
| Repository | `mise run cycle` | Full source loop |

## Development Workflow

```bash
# From $XDG_PROJECTS_DIR/github.com/laidback/laidback-dotfiles
mise run validate
mise run lint
mise run build
mise run test
```

Included quality gates:

- `shellcheck` — shell script linting
- `shfmt` — shell script formatting
- `markdownlint` — documentation linting
- `jq` — JSON syntax checks
- `hadolint` — Dockerfile linting
- `actionlint` — GitHub Actions workflow linting

## Local CI

```bash
cp .secrets.act.example .secrets.act
mise run ci:act
```

## Release Workflow

```bash
mise run release-check
mise run release:dry-run
mise run release:tag TAG=vX.Y.Z
mise run release:publish TAG=vX.Y.Z
```
