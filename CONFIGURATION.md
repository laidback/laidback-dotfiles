# Configuration Guide

This document explains how to configure a machine bootstrapped with
**laidback-dotfiles** — from first install through to advanced multi-identity
and secrets management.

---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/laidback/laidback-dotfiles/main/install.sh | bash
exec "${SHELL}"
```

That single command:

1. Installs **mise** (the tool manager) if absent.
2. Clones this repo to `$XDG_PROJECTS_DIR/github.com/laidback/laidback-dotfiles`
   (default: `~/projects/github.com/laidback/laidback-dotfiles`).
3. Stows all dotfiles from `home/` into `$HOME` via GNU Stow.
4. Installs all declared tool versions (`mise install`).
5. Installs **vim-plug** and all vim plugins.

No information is required from the user to complete the install.

---

## Project Layout

All repositories live under a structured tree rooted at `$XDG_PROJECTS_DIR`:

```text
~/projects/                       ← $XDG_PROJECTS_DIR (default)
  github.com/
    laidback/
      laidback-dotfiles/          ← this repo
      laidback-system/
  git.example.com/
    myorg/
      myproject/
```

Structure: `$XDG_PROJECTS_DIR/<forge>/<group>/<project>`

Clone a repo into the right place with:

```bash
mise run projects:clone https://git.example.com/myorg/myproject
```

### Overriding the projects root

Set `XDG_PROJECTS_DIR` **before** `env.sh` is sourced (i.e. before your shell
initialises). The simplest way is to put it in your shell's pre-env file:

```bash
# ~/.zshenv  or  ~/.profile  (before any laidback source lines)
export XDG_PROJECTS_DIR="$HOME/code"
```

Because `env.sh` uses `${XDG_PROJECTS_DIR:-$HOME/projects}`, a value set in
the environment always wins.

---

## Git Identity

After a fresh install **no git identity is configured** — the stowed
`~/.config/git/config` contains sane defaults but intentionally no `name` or
`email`.  git will warn on the first commit until you add one.

Identity configuration lives **outside this repo** so this repo is safe to
fork, make public, and share.  `dotfiles:status` and `dotfiles:doctor`
detect whatever you have configured and surface it automatically.

### Option A — Single identity (simplest)

If you use one name and email everywhere:

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

This writes directly into `~/.config/git/config` (which is stowed from the
repo).  The change is recorded in your fork of the dotfiles.  Do not push it
to a public fork unless you want your email public.

### Option B — Per-forge identity (recommended)

Repos live at `$XDG_PROJECTS_DIR/<forge>/<group>/<project>`.  git can select
a different identity per forge using `includeIf "gitdir:"`.  The override
files are **not part of this repo** — create them directly at
`~/.config/git/<forge>.config`.

**Step 1** — Create a config file per forge (examples):

```bash
# Personal forge (e.g. github.com)
cat > ~/.config/git/github.config <<'EOF'
[user]
  name  = Your Name
  email = you@personal.com
EOF

# Work forge
cat > ~/.config/git/mycompany.config <<'EOF'
[user]
  name  = Your Name
  email = you@company.com
EOF
```

**Step 2** — Add `includeIf` blocks to `home/.config/git/config` (the stowed
file) so git knows which config file to load for each forge:

```ini
[includeIf "gitdir:~/projects/github.com/"]
  path = ~/.config/git/github.config

[includeIf "gitdir:~/projects/git.mycompany.com/"]
  path = ~/.config/git/mycompany.config
```

**Step 3** — Restow and verify:

```bash
mise run bootstrap
git config user.name          # shows the identity for the current directory
mise run dotfiles:status      # "git identity" section lists configured forges
mise run dotfiles:doctor      # warns if no identity is set
```

### Verifying identity

```bash
mise run dotfiles:status   # shows user.name, user.email, and all forge configs found
mise run dotfiles:doctor   # WARN if user.name or user.email resolve to nothing
```

`dotfiles:status` scans `~/.config/git/` for any `*.config` files (excluding
the main `config`, `ignore`, and `attributes`) and lists them as forge
overrides.  No configuration is needed — they are discovered automatically.

> **Note:** git expands `~` but **not** environment variables in `gitdir:`
> patterns.  If you set a custom `XDG_PROJECTS_DIR` (e.g. `~/code`), use the
> literal expanded path in your `includeIf` blocks (e.g.
> `gitdir:~/code/github.com/`).

---

## Secrets Management (sops + age)

Tokens (`GITHUB_TOKEN`, `GLAB_TOKEN`, API keys, …) live in an sops-encrypted
file. The **plaintext never touches the repository**. `env.sh` auto-sources
the decrypted file at shell startup so every tool gets the tokens it needs.

### One-time setup (per machine)

```bash
mise run secrets:init     # 1. Generate your age keypair + scaffold secrets layout
mise run secrets:edit     # 2. Open encrypted file in $EDITOR — fill in your tokens
mise run secrets:decrypt  # 3. Write plaintext to ~/.config/laidback/secrets.env (0600)
exec "${SHELL}"           # 4. New shell auto-sources the tokens
```

Verify what's set (values are never printed):

```bash
mise run secrets:status
```

### Day-to-day commands

| Command | When to use |
| --- | --- |
| `mise run secrets:edit` | Add or rotate a token |
| `mise run secrets:decrypt` | Refresh the plaintext file after editing |
| `mise run secrets:status` | Check which variables are present |
| `mise run secrets:init` | First run on a new machine |

### File locations

| File | Location | Committed? |
| --- | --- | --- |
| Encrypted secrets | `~/.config/laidback/secrets.env.sops` | No — lives outside the repo |
| Decrypted plaintext | `~/.config/laidback/secrets.env` | Never — mode 0600, auto-deleted on re-init |
| Your age private key | `~/.config/sops/age/keys.txt` | Never — back this up securely |
| sops creation rules | `~/.config/laidback/.sops.yaml` | No — auto-generated by `secrets:init` |

### Key backup

Your age private key is the only way to decrypt your secrets.
Back it up somewhere secure (password manager, printed QR, encrypted USB):

```bash
cat ~/.config/sops/age/keys.txt
```

---

## Advanced: Secrets Scopes

### Fully private (default)

Everything above — secrets are encrypted with **your** age key alone and never
leave your machine. Suitable for personal tokens (GITHUB_TOKEN, etc.).

### Per-project local override

For secrets that belong to a specific project but are still yours only, drop an
unencrypted `.env.local` at the project root (add it to `~/.config/git/ignore`
or the project's `.gitignore`):

```bash
# ~/projects/github.com/myorg/myproject/.env.local
export MY_PROJECT_API_KEY=secret
```

Source it explicitly or use `mise`'s `env` support in the project's
`mise.toml`:

```toml
[env]
_.file = ".env.local"
```

### Team-shared secrets

When a team needs to share tokens (e.g., a staging API key), commit an
`sops`-encrypted file **inside the project repo** with all team members as
recipients.

1. Collect each teammate's age public key:

   ```bash
   # Each person runs:
   grep "^# public key:" ~/.config/sops/age/keys.txt | awk '{print $NF}'
   ```

2. Create `.sops.yaml` at the project root:

   ```yaml
   creation_rules:
     - path_regex: secrets\.env\.sops$
       age: "age1alice...,age1bob...,age1carol..."
   ```

3. Create and encrypt the secrets file:

   ```bash
   sops --encrypt --input-type dotenv --output-type dotenv secrets.env > secrets.env.sops
   git add .sops.yaml secrets.env.sops
   git rm --cached secrets.env   # ensure plaintext is never committed
   ```

4. Any team member with their key can decrypt:

   ```bash
   sops --decrypt secrets.env.sops > secrets.env
   ```

5. Rotate (add/remove a key): update `.sops.yaml`, then:

   ```bash
   sops updatekeys secrets.env.sops
   ```

---

## Reference: Environment Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `XDG_PROJECTS_DIR` | `~/projects` | Root of the project tree |
| `XDG_CONFIG_HOME` | `~/.config` | XDG config root |
| `XDG_DATA_HOME` | `~/.local/share` | XDG data root |
| `XDG_STATE_HOME` | `~/.local/state` | XDG state root |
| `XDG_CACHE_HOME` | `~/.cache` | XDG cache root |
| `LAIDBACK_FORGE` | `github.com/laidback` | Primary forge / org path segment |
| `LAIDBACK_DOTFILES_ROOT` | `$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/laidback-dotfiles` | Path to this repo |
| `LAIDBACK_CONFIG` | `$XDG_CONFIG_HOME/laidback` | Laidback runtime config (secrets, etc.) |

Set any of these in your shell's pre-env file (`~/.zshenv` / `~/.profile`)
**before** laidback's `env.sh` is sourced and the defaults will be respected.

---

## Contributing a Feature

This section walks through the full lifecycle of adding something new to the
dotfiles repo — from understanding the current state of your machine, through
implementation, to a clean commit on `main`.

### Step 1 — Orient yourself

Before touching anything, ask: *what is live on this machine right now?*

```bash
# From anywhere — requires bootstrap to have run at least once
mise run dotfiles:status    # environment + every stow symlink
mise run dotfiles:doctor    # health checks — all must say PASS or WARN
```

**`dotfiles:status` reads:**

| Section | What it tells you |
| --- | --- |
| `environment` | Active XDG paths, forge, dotfiles root |
| `repository` | Current branch + HEAD commit of the dotfiles repo |
| `stow symlinks` | Which dotfiles are live (symlink → repo / plain / MISSING) |
| `global tasks` | Whether `dotfiles:status` and `dotfiles:doctor` are executable |
| `tools` | Version of every managed tool (`mise`, `git`, `vim`, `kubectl`, …) |

**`dotfiles:doctor` checks:**

- All required stow symlinks (env.sh, git/config, .vimrc, …) are live.
- No plain `~/.gitconfig` is overriding the XDG config.
- vim-plug and `kubectl-view_secret` were installed by bootstrap.
- All required tools are reachable in `$PATH`.

If doctor has failures, resolve them before writing new code.

### Step 2 — Branch

Always branch off `main`; never work directly on main.

```bash
cd "$LAIDBACK_DOTFILES_ROOT"
git switch -c feat/<short-description>
```

### Step 3 — Understand the file map

Every feature that touches the home environment involves a consistent set of
files. Here is what each one does and why it is usually modified together:

| File | Role | Modified when |
| --- | --- | --- |
| `home/.config/git/config` | Stowed to `~/.config/git/config` — git global config | New git behaviour, alias, or identity rule |
| `home/.config/git/ignore` | Stowed to `~/.config/git/ignore` — global gitignore | New file pattern to ignore everywhere |
| `home/.config/mise/tasks/dotfiles/doctor.sh` | Global health-check task | New thing to validate post-bootstrap |
| `home/.config/mise/tasks/dotfiles/status.sh` | Global status overview task | New symlink or tool to surface in status |
| `mise/config.toml` | All repo tasks + bootstrap logic + inline doctor/status | New tool install step, new task, new check |
| `Dockerfile` | CI test image — must mirror bootstrap exactly | New system package or binary validation |
| `.gitignore` | Belt-and-braces for secrets / machine-local files | New per-machine artifact introduced |
| `README.md` / `CONFIGURATION.md` | User-facing docs | User-visible behaviour change |

> **Rule of thumb:** if you add something to `bootstrap`, add the matching
> health check to `doctor` and the matching line to `status`. If it installs a
> binary, add it to the Dockerfile too.

### Step 4 — Implement

Make your changes. The typical loop is:

```bash
# Format shell scripts after editing
mise run fmt

# Lint everything (shellcheck, markdownlint, hadolint, actionlint, jq)
mise run lint

# Apply bootstrap to your live machine and check the result
mise run bootstrap
mise run dotfiles:status
mise run dotfiles:doctor
```

### Step 5 — Full cycle (source loop)

`cycle` runs `bootstrap → status → validate` in one shot. This is the
canonical "does everything still work?" gate:

```bash
mise run cycle
```

- **`bootstrap`** — restows `home/`, installs tools and plugins.
- **`status`** — prints what is live; visually confirm your new feature appears.
- **`validate`** — runs `doctor` + all linters; must exit 0.

### Step 6 — Docker smoke test

The Docker test stage mirrors a clean bootstrap on a fresh Debian host.
It catches anything that only works because your local machine already had
something installed:

```bash
mise run docker:test
```

This rebuilds the image from scratch and asserts every binary and symlink the
bootstrap task is supposed to produce actually exists.

### Step 7 — Clean up and commit

```bash
# Final gate — the same thing CI runs
mise run validate

# Verify nothing unintended is staged
git diff --stat HEAD

# Stage and commit
git add -A
git commit -m "feat(<scope>): <what and why>"

# Push and open a PR
git push -u origin feat/<short-description>
```

Commit message convention: `<type>(<scope>): <imperative summary>`.
Common types: `feat`, `fix`, `docs`, `chore`, `refactor`.
Common scopes: `bootstrap`, `git`, `vim`, `kubectl`, `shell`, `docker`, `docs`.

### Step 8 — Merge to main

After CI passes on the PR, merge with a standard merge commit (no squash, no
rebase — preserves the full change history per-feature). Then update your
local main:

```bash
git switch main
git pull --ff-only
mise run bootstrap   # pick up any changes merged from other branches
exec "${SHELL}"
```

### Quick reference

```bash
# Orient
mise run dotfiles:status          # what is live on this machine
mise run dotfiles:doctor          # are all checks green

# Develop
mise run fmt                      # format shell scripts
mise run lint                     # all linters
mise run bootstrap                # apply changes to live $HOME
mise run cycle                    # bootstrap + status + validate (full source loop)

# Verify
mise run docker:test              # full clean-machine simulation
mise run validate                 # doctor + lint (CI gate)

# Release
git add -A && git commit -m "..."
git push -u origin feat/<branch>
# open PR → CI passes → merge → git switch main && git pull --ff-only
```
