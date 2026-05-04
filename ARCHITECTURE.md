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
│   │   └── tasks/
│   │       ├── dotfiles/               # Global lifecycle tasks
│   │       │   ├── status.sh
│   │       │   └── doctor.sh
│   │       └── projects/               # Global project-management tasks
│   │           ├── clone.sh            # mise run projects:clone <git-url>
│   │           └── fingerprint.sh      # mise run projects:fingerprint [path]
│   ├── shell/
│   │   ├── env.sh                      # Sourced LAIDBACK + XDG defaults
│   │   └── motd.sh                     # Mode-aware MOTD (silent in human mode)
│   ├── starship.toml                   # Prompt: shell + shlvl indicators
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

### Prompt & MOTD

The prompt and the MOTD share the work of telling the user / automation what shell they are
currently running inside:

- **Starship prompt** (`home/.config/starship.toml`) renders on every command line and is the
  authoritative interactive signal:
  - `[shell]` module (always visible, cyan): `[zsh]`, `[bash]`, `[fish]`, …
  - `[shlvl]` module (yellow, threshold 2): `↕2`, `↕3`, … only when nested.
  - Both modules are prepended to the left format so the shell label is the first token of every
    prompt line.
- **MOTD** (`home/.config/shell/motd.sh`):
  - Silent in `LAIDBACK_EXECUTION_MODE=human` (the prompt already carries the signal).
  - Prints `[<mode> <shell>] <dir>[ git=<branch>]` once per `(shell, mode, dir)` tuple in `ai`
    and `ci` modes — useful as a parseable breadcrumb in agent / CI logs.
  - Cache file: `$XDG_STATE_HOME/laidback/motd_last`.
  - `LAIDBACK_FORCE_MOTD=1` overrides the human-mode short-circuit (testing).

Terminology recap:

- **Terminal emulator** — the GUI app (VS Code terminal, iTerm2, …); owns the pty.
- **Shell** — the program inside the pty (`zsh`, `bash`, …); switching with `bash`/`zsh`
  spawns a *child* process, you do not replace the terminal.
- **Prompt renderer** — starship; same binary + same config drives both shells, hence the need
  for the explicit `[zsh]` / `[bash]` indicator.

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

Use `mise run projects:clone <git-url>` (a global task installed by bootstrap) to clone
any repository into the deterministic forge layout, and `mise run projects:fingerprint`
to introspect a project's languages, services, and ports.

- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR`
- `XDG_PROJECTS_DIR`
- `LAIDBACK_CONFIG`, `LAIDBACK_DATA`, `LAIDBACK_STATE`, `LAIDBACK_CACHE`
- `LAIDBACK_MISE_TASKS_HOME`
- `MISE_CONFIG_DIR`, `MISE_DATA_DIR`, `MISE_STATE_DIR`, `MISE_CACHE_DIR`, `MISE_TASKS_DIR`

### Security

- Secret tooling: `sops`, `age`
- Task gate: `mise run security:sops-check`

## Task Topology

The repository config `mise/config.toml` is the source-loop task provider for this repo.
After bootstrap, the global namespaced tasks under `~/.config/mise/tasks/{dotfiles,projects}/`
are available system-wide.

Global tasks (anywhere, post-bootstrap):

- `dotfiles:status` — environment + symlink overview
- `dotfiles:doctor` — health checks
- `projects:clone <git-url>` — forge-deterministic clone
- `projects:fingerprint [path]` — language / service / port detection

Repository tasks (run from inside the cloned dotfiles repo):

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
- Keep task definitions centralized in `mise/config.toml`.
- No secrets in git. The `.gitignore` lists per-machine artifacts (`.secrets.act`,
  `home/.aws/`, `home/.kube/`, `home/.config/glab-cli/`, `home/.config/.jira.d/`,
  `ZscalerRootCA.pem`).
