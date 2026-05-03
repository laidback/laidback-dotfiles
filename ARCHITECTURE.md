# ARCHITECTURE

Dotfiles is a home-environment control layer for laidback development.

## Target LAIDBACK_HOME

```text
$HOME/
├── .zshrc
├── .zprofile
├── .bashrc.ai
├── .bash_profile.ai
├── .profile
├── .aws/
│   └── config                  # default AWS config (stowed)
├── .kube/
│   └── config                  # default Kubernetes config (stowed)
├── .config/
│   ├── mise/
│   │   ├── config.toml                 # Global mise config
│   │   ├── conf.d/
│   │   │   ├── 01-base.toml
│   │   │   └── 02-tools.toml
│   │   └── tasks/
│   │       ├── dotfiles/               # Global user tasks
│   │       │   ├── bootstrap
│   │       │   ├── status
│   │       │   ├── doctor
│   │       │   ├── ai-bash
│   │       │   └── secrets
│   │       └── ...
│   ├── starship.toml
│   ├── gh/
│   │   └── config.yml
│   ├── glab-cli/                       # or glab.toml
│   ├── .jira.d/
│   └── ai-agents/
├── .local/
│   └── bin/
│       └── ai-bash                     # Clean AI shell
├── .github/
│   └── copilot-instructions.md
└── projects/
    └── laidback-system.code-workspace
```

## Purpose

- Keep user shell behavior deterministic for human interactive usage and AI/script usage.
- Keep all state XDG-compliant.
- Keep secrets management explicit with sops and age.
- Use mise for both global and project-local tasks, tools, and environment controls.

## Runtime Model

### Shell Modes

- Interactive mode: user shell (`zsh`) with readable pager defaults.
- Automation mode: script/AI shell (`bash`) with non-interactive pager/editor defaults.

### Core Environment

The core environment variable for this project is `LAIDBACK_DOTFILES_ROOT`.
It is derived from `LAIDBACK_FORGE`, the org/forge path segment:

```text
$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/<PROJECT>

LAIDBACK_FORGE=github.com/laidback
<PROJECT>=laidback-dotfiles
$LAIDBACK_DOTFILES_ROOT=$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/laidback-dotfiles
```

Other laidback repos (`laidback-system`, `gitops-bootstrap`, ...) follow the same
forge/group/project layout but define their own `LAIDBACK_<ROLE>_ROOT` variables
in their own env files. Dotfiles intentionally does **not** export sibling-repo
roots — it stays decoupled from the rest of the stack.

Use `mise run clone <git-url>` (a global task installed by bootstrap) to clone
any repository into the deterministic forge layout.

- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR`
- `XDG_PROJECTS_DIR`
- `LAIDBACK_CONFIG`, `LAIDBACK_DATA`, `LAIDBACK_STATE`, `LAIDBACK_CACHE`
- `LAIDBACK_MISE_TASKS_HOME`
- `MISE_CONFIG_DIR`, `MISE_DATA_DIR`, `MISE_STATE_DIR`, `MISE_CACHE_DIR`, `MISE_TASKS_DIR`

### Security

- Secret tooling: `sops`, `age`
- Task gate: `mise run security:sops-check`

## Task Topology

The repository root `mise.toml` is the source-loop task provider.

Primary tasks:

- `bootstrap`
- `status`
- `doctor`
- `fmt`
- `lint`
- `validate`
- `build`
- `test`
- `cycle`
- `release-check`
- `release:dry-run`
- `release:tag`
- `release:publish`

Supporting lint tasks:

- `shell:lint` (shellcheck)
- `docs:lint` (markdownlint)
- `json:lint` (jq syntax checks)
- `docker:lint` (hadolint)
- `ci:workflow-validate` (actionlint)
- `ci:act` (local workflow simulation)

## CI

CI uses root mise tasks only:

- install tools with `mise install`
- run `mise run validate`
- run `mise run build`

## Repository Rules

- Lower-case repository paths by default under `$XDG_PROJECTS_DIR/github.com/laidback`.
- Keep docs limited to `README.md` and `ARCHITECTURE.md`.
- Keep task definitions centralized in root `mise.toml`.
