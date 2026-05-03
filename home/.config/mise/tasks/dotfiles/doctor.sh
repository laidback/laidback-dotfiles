#!/usr/bin/env bash
# @description: Run dotfiles health check (available system-wide after bootstrap)
set -euo pipefail

: "${LAIDBACK_FORGE:=github.com/laidback}"
: "${XDG_PROJECTS_DIR:=$HOME/projects}"
: "${LAIDBACK_DOTFILES_ROOT:=$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/laidback-dotfiles}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"

_pass() { printf "  %-38s PASS\n"     "$1"; }
_fail() { printf "  %-38s FAIL  %s\n" "$1" "$2"; _errors=$((_errors + 1)); }
_warn() { printf "  %-38s WARN  %s\n" "$1" "$2"; }
_errors=0

_check() {
    local label="$1" cond="$2" msg="${3:-}"
    if eval "$cond" >/dev/null 2>&1; then
        _pass "$label"
    elif [ -n "$msg" ]; then
        _warn "$label" "$msg"
    else
        _fail "$label" "(see above)"
    fi
}

_require() {
    local label="$1" cond="$2" msg="${3:-}"
    if eval "$cond" >/dev/null 2>&1; then
        _pass "$label"
    else
        _fail "$label" "$msg"
    fi
}

echo "======================================================================"
echo "  laidback-dotfiles  doctor"
echo "======================================================================"
echo ""

# Repository
_require "repo: dotfiles present"          "[ -d \"$LAIDBACK_DOTFILES_ROOT/.git\" ]"  "not found at $LAIDBACK_DOTFILES_ROOT"

# Stow symlinks
_require "stow: env.sh symlinked"          "[ -L \"$HOME/.config/shell/env.sh\" ]"        "run: mise run bootstrap"
_check   "stow: mise/config.toml"          "[ -L \"$HOME/.config/mise/config.toml\" ]"    "not a symlink — may not track changes"
_check   "stow: .zshrc"                    "[ -L \"$HOME/.zshrc\" ]"                      "not a symlink"
_check   "stow: .zprofile"                 "[ -L \"$HOME/.zprofile\" ]"                   "not a symlink"
_check   "stow: .profile"                  "[ -L \"$HOME/.profile\" ]"                    "not a symlink"

# Shell foundation
if [ -e "$HOME/.config/shell/env.sh" ]; then
    _check "env.sh: XDG_PROJECTS_DIR defined" \
        "grep -q XDG_PROJECTS_DIR \"$HOME/.config/shell/env.sh\"" \
        "not found in env.sh"
fi

# Required tools
_require "tool: mise"  "command -v mise"  "not in PATH"
_require "tool: git"   "command -v git"   "not in PATH"

# Optional tools
_check "tool: stow"  "command -v stow"  "not installed — bootstrap will auto-install"
_check "tool: gh"    "command -v gh"    "optional: mise install gh"
_check "tool: sops"  "command -v sops"  "optional: mise install sops"
_check "tool: age"   "command -v age"   "optional: mise install age"

# Global tasks
_require "global task: dotfiles:status"  "[ -x \"$HOME/.config/mise/tasks/dotfiles/status.sh\" ]"  "run: mise run bootstrap"
_require "global task: dotfiles:doctor"  "[ -x \"$HOME/.config/mise/tasks/dotfiles/doctor.sh\" ]"  "run: mise run bootstrap"

echo ""
if [ "$_errors" -eq 0 ]; then
    echo "  doctor: ok"
else
    printf "  doctor: %d check(s) failed\n" "$_errors"
    exit 1
fi
echo "======================================================================"
