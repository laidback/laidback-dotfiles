#!/usr/bin/env bash
# ================================================================
# LAIDBACK HOME — install.sh
# First-time bootstrap for a fresh or existing machine.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/laidback/laidback-dotfiles/main/install.sh | bash
# ================================================================

set -euo pipefail

# ------------------------------------------------------------------
# 1. XDG Base Directories (Early — needed before everything else)
# ------------------------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_PROJECTS_DIR="${XDG_PROJECTS_DIR:-$HOME/projects}"

# ------------------------------------------------------------------
# 2. Laidback env vars (canonical project paths)
# ------------------------------------------------------------------
# LAIDBACK_FORGE is the forge/org path segment (not a full directory)
export LAIDBACK_FORGE="${LAIDBACK_FORGE:-github.com/laidback}"
# LAIDBACK_DOTFILES_ROOT is the full path to the cloned dotfiles repository
export LAIDBACK_DOTFILES_ROOT="${LAIDBACK_DOTFILES_ROOT:-$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/laidback-dotfiles}"

echo "======================================================================"
echo "               LAIDBACK HOME Bootstrap (mise-powered)                "
echo "======================================================================"
echo "OS/Arch  : $(uname -s)/$(uname -m)"
echo "Started  : $(date)"
echo "Target   : $LAIDBACK_DOTFILES_ROOT"
echo ""

# ------------------------------------------------------------------
# 3. Detect OS / arch
# ------------------------------------------------------------------
echo "→ [1/4] Detecting platform..."
_os="$(uname -s)"
_arch="$(uname -m)"
case "$_os" in
    Darwin | Linux) echo "  platform: $_os/$_arch — supported" ;;
    *)
        echo "  unsupported OS: $_os" >&2
        exit 1
        ;;
esac

# ------------------------------------------------------------------
# 4. Ensure mise
# ------------------------------------------------------------------
echo "→ [2/4] Checking mise..."
if ! command -v mise >/dev/null 2>&1; then
    echo "  mise not found — installing via mise.run..."
    curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
echo "  mise $(mise --version)"

# ------------------------------------------------------------------
# 5. Ensure git
# ------------------------------------------------------------------
echo "→ [3/4] Checking git..."
if ! command -v git >/dev/null 2>&1; then
    echo "  git not found — attempting to install..."
    case "$_os" in
        Darwin)
            echo "  install Xcode Command Line Tools and re-run:" >&2
            echo "    xcode-select --install" >&2
            exit 1
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y git
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y git
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm git
            else
                echo "  cannot install git automatically — install it manually and re-run" >&2
                exit 1
            fi
            ;;
    esac
fi
echo "  git $(git --version)"

# ------------------------------------------------------------------
# 6. Clone or update repository
# ------------------------------------------------------------------
# Resolve the directory where this script lives (works for both file and pipe execution)
_script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# If running from within an existing dotfiles checkout, use it directly
if [ -n "$_script_dir" ] && [ -f "$_script_dir/home/.config/shell/env.sh" ]; then
    LAIDBACK_DOTFILES_ROOT="$_script_dir"
    echo "→ [4/4] Using existing dotfiles directory: $LAIDBACK_DOTFILES_ROOT"
    # Pull latest if it is a git repo
    if [ -d "$LAIDBACK_DOTFILES_ROOT/.git" ]; then
        git -C "$LAIDBACK_DOTFILES_ROOT" pull --ff-only 2>/dev/null || echo "  (skipped pull — not on a tracking branch)"
    fi
else
    echo "→ [4/4] Setting up repository at $LAIDBACK_DOTFILES_ROOT..."
    mkdir -p "$(dirname "$LAIDBACK_DOTFILES_ROOT")"
    if [ -d "$LAIDBACK_DOTFILES_ROOT/.git" ]; then
        echo "  already cloned — pulling latest..."
        git -C "$LAIDBACK_DOTFILES_ROOT" pull --ff-only
    else
        git clone "https://$LAIDBACK_FORGE/laidback-dotfiles" "$LAIDBACK_DOTFILES_ROOT"
        echo "  cloned to $LAIDBACK_DOTFILES_ROOT"
    fi
fi

# ------------------------------------------------------------------
# 7. Bootstrap
# ------------------------------------------------------------------
cd "$LAIDBACK_DOTFILES_ROOT"

# Install env.sh early so we can source it before mise runs stow.
# Skip the copy if stow has already created a symlink (idempotent re-run).
mkdir -p "$HOME/.config/shell"
if [ -L "$HOME/.config/shell/env.sh" ]; then
    echo "  env.sh: already symlinked — skipping pre-stow copy"
else
    cp -f home/.config/shell/env.sh "$HOME/.config/shell/env.sh"
    echo "  env.sh: copied to $HOME/.config/shell/env.sh"
fi

# Source env now for the rest of this install
# shellcheck source=home/.config/shell/env.sh
. "$HOME/.config/shell/env.sh"

echo ""
echo "→ Running bootstrap (stow + global tasks)..."
mise install --yes
# Trust this directory's mise config so global tasks (dotfiles:status etc.)
# can invoke mise from within this repo without an interactive trust prompt.
mise trust --yes
mise run bootstrap

# ------------------------------------------------------------------
# 8. Return to home
# ------------------------------------------------------------------
cd "$HOME"
echo ""
echo "======================================================================"
echo "LAIDBACK HOME  bootstrap completed"
echo ""
echo "  Environment"
printf "  %-22s %s\n" "HOME"              "$HOME"
printf "  %-22s %s\n" "XDG_PROJECTS_DIR"  "${XDG_PROJECTS_DIR:-$HOME/projects}"
printf "  %-22s %s\n" "LAIDBACK_FORGE"          "$LAIDBACK_FORGE"
printf "  %-22s %s\n" "LAIDBACK_DOTFILES_ROOT"  "$LAIDBACK_DOTFILES_ROOT"
printf "  %-22s %s\n" "XDG_CONFIG_HOME"   "${XDG_CONFIG_HOME:-$HOME/.config}"
printf "  %-22s %s\n" "XDG_DATA_HOME"     "${XDG_DATA_HOME:-$HOME/.local/share}"
echo ""
echo "  Key paths"
printf "  %-22s %s\n" "env.sh"            "$HOME/.config/shell/env.sh"
printf "  %-22s %s\n" "mise config"       "$HOME/.config/mise/config.toml"
printf "  %-22s %s\n" "global tasks"      "$HOME/.config/mise/tasks/dotfiles/"
echo ""
echo "  Commands (anywhere, after shell restart)"
echo "    mise run dotfiles:status   — check bootstrap state"
echo "    mise run dotfiles:doctor   — run health checks"
echo ""
echo "  Commands (from \$LAIDBACK_DOTFILES_ROOT)"
echo "    mise run validate          — full lint + validation"
echo "    mise run lint              — linters only"
echo "    mise run cycle             — format + validate"
echo ""
echo "  Restart your shell"
echo "    exec \${SHELL}"
echo "======================================================================"