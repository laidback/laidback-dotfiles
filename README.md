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

After bootstrap, global `dotfiles:*` and `projects:*` tasks are available system-wide via mise.
Repository tasks for development and release are available from the cloned project directory.

## Key Features

- **Shell Control**: Distinct behavior for interactive human usage and AI/script usage.
- **Visible Shell Indicator**: Starship prompt prepends `[zsh]`/`[bash]` (cyan) on every line, plus
  `↕5`-style nesting depth (yellow) when `SHLVL ≥ 2` — you always know which shell you're in and
  whether it's nested.
- **Mode-Aware MOTD**: Silent in interactive human mode (the prompt already shows shell + dir).
  Prints a structured one-liner in `ai` / `ci` modes (`LAIDBACK_EXECUTION_MODE=ai|ci`) for
  log breadcrumbs.
- **Environment Control**: Centralized defaults in `home/.config/shell/env.sh` with explicit
  LAIDBACK/XDG variables.
- **XDG Compliance**: Home state follows XDG paths for config/data/state/cache/runtime.
- **Secrets Ready**: `sops` + `age` checks integrated into management tasks. No secrets ship in
  this repo — see `.gitignore` for the per-machine ignore list (`.secrets.act`, `home/.aws/`,
  `home/.kube/`, `ZscalerRootCA.pem`, …).
- **Mise First**: One root mise config controls repository-local tasks/tools; home config supports
  global use via `MISE_TASKS_DIR`.
- **Global Tasks**: `dotfiles:status`, `dotfiles:doctor`, `projects:clone`, `projects:fingerprint`
  available anywhere after bootstrap.

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
mise run dotfiles:status               # environment + stow symlink overview
mise run dotfiles:doctor               # health checks
mise run projects:clone <git-url>      # clone into $XDG_PROJECTS_DIR/<forge>/<group>/<project>
mise run projects:fingerprint [path]   # detect languages / services / ports for a project
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for full variable and topology details.
See [CONFIGURATION.md](CONFIGURATION.md) for the full configuration guide — git identities, secrets, and advanced usage.

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
| Anywhere | `mise run projects:clone <url>` | Forge-deterministic clone |
| Anywhere | `mise run projects:fingerprint [path]` | Project introspection |
| Repository | `mise run secrets:init` | One-time age + sops bootstrap |
| Repository | `mise run secrets:edit` | Edit encrypted tokens via sops |
| Repository | `mise run secrets:decrypt` | Refresh plaintext at `$LAIDBACK_CONFIG/secrets.env` |
| Repository | `mise run secrets:status` | Verify variable presence (no values) |
| Repository | `mise run status` | Direct task from `mise/config.toml` |
| Repository | `mise run doctor` | Direct task from `mise/config.toml` |
| Repository | `mise run validate` | Full validation gate |
| Repository | `mise run cycle` | Full source loop |

## Prompt & MOTD

The starship prompt (`home/.config/starship.toml`) shows two interactive signals on every line:

- `[zsh]` / `[bash]` (cyan) — which shell binary owns the current pty.
- `↕2`, `↕3`, … (yellow) — only when `SHLVL ≥ 2` (you nested a shell inside another shell).

The MOTD (`home/.config/shell/motd.sh`) is intentionally silent in human mode, since the prompt
already carries the shell signal. It prints one structured line in non-interactive contexts:

```text
[ai bash] /path/to/project git=feature/x
[ci zsh]  /path/to/project git=main
```

Mode is controlled by `LAIDBACK_EXECUTION_MODE` (`human` | `ai` | `ci`, default `human`).
Set `LAIDBACK_FORCE_MOTD=1` to force the line in human mode for testing.

## Secrets (sops + age)

User-environment tokens (`GITHUB_TOKEN`, `GLAB_TOKEN`, `JIRA_API_TOKEN`,
`ANTHROPIC_API_KEY`, …) are managed through `sops` + `age` and live **outside**
this git repo at `$LAIDBACK_CONFIG/secrets.env(.sops)` (=
`$XDG_CONFIG_HOME/laidback/secrets.env(.sops)`). They are sourced into every
shell automatically by `home/.config/shell/env.sh` when present.

### One-time setup

```bash
mise install                   # ensures sops + age are present (already in mise/config.toml)
mise run secrets:init          # generates an age keypair, writes .sops.yaml, seeds secrets.env.sops from the template
mise run secrets:edit          # opens the encrypted file in $EDITOR via sops; fill in your tokens
mise run secrets:decrypt       # writes plaintext to $LAIDBACK_CONFIG/secrets.env (chmod 600)
exec $SHELL -l                 # reload — env.sh now exports the tokens
mise run secrets:status        # verifies presence (no values printed)
```

### Daily edits

```bash
mise run secrets:edit          # sops re-encrypts on save
mise run secrets:decrypt       # refresh the plaintext copy
exec $SHELL -l                 # or open a new terminal
```

### What the variables look like

The canonical list is shipped as the safe-to-commit template
[`home/.config/laidback/secrets.env.example`](home/.config/laidback/secrets.env.example),
which is stowed to `~/.config/laidback/secrets.env.example`. It enumerates the
tokens the laidback stack expects (GitHub, GitLab, Jira, GHCR, LLM providers).
Empty values are fine — only the ones you need actually have to be filled.

### How leakage is prevented

1. **The decrypted file lives outside this repo** (`$LAIDBACK_CONFIG/secrets.env`),
   so a stray `git add` cannot pick it up.
2. **`.gitignore`** belt-and-braces matches `secrets.env`, `**/secrets.env`,
   `home/.config/laidback/secrets.env`, and `home/.config/sops/age/keys.txt` —
   even if a copy were dropped inside the repo, git would refuse to track it.
3. **`env.sh` enforces mode `0600` (or `0400`)** on the plaintext file before
   sourcing it; a too-open file is rejected with a printed warning instead of
   silently exporting on a shared system.
4. **The encrypted `.sops` file is safe to commit anywhere** (e.g. a private
   `dotfiles-secrets` repo). Without the matching age private key it is
   opaque ciphertext.
5. **The age private key** at `~/.config/sops/age/keys.txt` is `chmod 700` on
   the directory, `chmod 600` on the file, and never enters this repo.

### Multi-machine

To use the same secrets on another machine, share the encrypted file and the
age private key out-of-band (1Password, hardware token, encrypted USB):

```bash
# on the new machine, after `mise run secrets:init` has created an empty layout:
cp /path/to/keys.txt        ~/.config/sops/age/keys.txt && chmod 600 $_
cp /path/to/secrets.env.sops $LAIDBACK_CONFIG/secrets.env.sops
mise run secrets:decrypt
```

To rotate the recipient set (add a colleague's public key), edit
`$LAIDBACK_CONFIG/.sops.yaml` and re-encrypt with `sops updatekeys
$LAIDBACK_CONFIG/secrets.env.sops`.

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

On macOS, `markdownlint`, `starship`, and `bash` are required to come from Homebrew.
`dotfiles:doctor` enforces this (`bash` must be Homebrew Bash 5+, not the system `/bin/bash` 3.2).

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

## Versioning

This repository follows [Semantic Versioning](https://semver.org/). The current baseline is
`v0.1.0` — first publicly shareable cut covering bootstrap, stow layout, mode-aware MOTD,
starship shell + nesting indicators, namespaced global tasks (`dotfiles:*`, `projects:*`),
Docker validation, and full GitHub Actions CI. `v0.2.0` adds the `secrets:*` task family
(sops + age user-token management).
