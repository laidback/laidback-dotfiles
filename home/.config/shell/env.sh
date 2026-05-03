#!/usr/bin/env sh
# ================================================================
# .config/shell/env.sh
# Core XDG + Laidback environment — Sourced by ALL shells
#
# Variable tiers:
#   Tier 0 — XDG (standard)
#   Tier 1 — LAIDBACK_{CONFIG,DATA,STATE,CACHE,RUNTIME}  (shared runtime)
#   Tier 2 — LAIDBACK_<REPO>_ROOT                         (per-repo dev path)
#   Tier 3 — Per-skill subpaths                           (convention only)
#
# All Tier-2 variables are *paths*, not requirements — they may not exist on
# every machine. shiftctl and other tools must tolerate missing dev roots.
# ================================================================

[ -n "${LAIDBACK_ENV_SOURCED:-}" ] && return 0
LAIDBACK_ENV_SOURCED=1

# ── Tier 0: XDG Base Directories ─────────────────────────────────────────────
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    _uid="$(id -u 2>/dev/null || echo 0)"
    case "$(uname -s)" in
        Darwin) XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/runtime-${_uid}" ;;
        *)      XDG_RUNTIME_DIR="/run/user/${_uid}" ;;
    esac
    unset _uid
fi

XDG_PROJECTS_DIR="${XDG_PROJECTS_DIR:-$HOME/projects}"

export XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR XDG_PROJECTS_DIR

# ── Tier 1: shared Laidback runtime (defined once, used by all repos) ────────
LAIDBACK_FORGE="${LAIDBACK_FORGE:-github.com/laidback}"
LAIDBACK_CONFIG="${LAIDBACK_CONFIG:-$XDG_CONFIG_HOME/laidback}"
LAIDBACK_DATA="${LAIDBACK_DATA:-$XDG_DATA_HOME/laidback}"
LAIDBACK_STATE="${LAIDBACK_STATE:-$XDG_STATE_HOME/laidback}"
LAIDBACK_CACHE="${LAIDBACK_CACHE:-$XDG_CACHE_HOME/laidback}"
LAIDBACK_RUNTIME="${LAIDBACK_RUNTIME:-$XDG_RUNTIME_DIR/laidback}"

export LAIDBACK_FORGE LAIDBACK_CONFIG LAIDBACK_DATA LAIDBACK_STATE LAIDBACK_CACHE LAIDBACK_RUNTIME

# ── Tier 2: this repo's dev root ─────────────────────────────────────────────
# Other laidback repos define their own LAIDBACK_<ROLE>_ROOT in their own
# env files — dotfiles only knows about itself, so it stays decoupled.
LAIDBACK_DOTFILES_ROOT="${LAIDBACK_DOTFILES_ROOT:-$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/laidback-dotfiles}"

export LAIDBACK_DOTFILES_ROOT

# ── Mise (XDG-compliant paths) ───────────────────────────────────────────────
MISE_CONFIG_DIR="${MISE_CONFIG_DIR:-$XDG_CONFIG_HOME/mise}"
MISE_DATA_DIR="${MISE_DATA_DIR:-$XDG_DATA_HOME/mise}"
LAIDBACK_MISE_TASKS_HOME="${LAIDBACK_MISE_TASKS_HOME:-$XDG_CONFIG_HOME/mise/tasks}"

export MISE_CONFIG_DIR MISE_DATA_DIR LAIDBACK_MISE_TASKS_HOME

# ── PATH ─────────────────────────────────────────────────────────────────────
PATH="$HOME/.local/bin:$PATH"
PATH="$MISE_DATA_DIR/shims:$PATH"
export PATH

export LAIDBACK_ENV_READY=1
