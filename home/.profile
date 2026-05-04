# ~/.profile — POSIX login shell configuration
# Sourced by sh, bash (when no .bash_profile), and dash.
# shellcheck shell=sh

# shellcheck source=.config/shell/env.sh
. "$HOME/.config/shell/env.sh"

# mise path (covers shells that don't load env.sh via $PATH)
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
export PATH

# Optional tool envs — guarded so missing installs don't break login
# Turso (edge database CLI)
# shellcheck disable=SC1091
[ -f "$HOME/.turso/env" ] && . "$HOME/.turso/env"

# Rust / cargo
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
