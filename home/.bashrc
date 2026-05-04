# ~/.bashrc — Interactive bash configuration
# shellcheck shell=bash
# Sourced for every interactive bash session.

# ── Environment foundation ──────────────────────────────────────────────────
# shellcheck source=.config/shell/env.sh
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

# Return early in non-interactive shells.
case $- in
*i*) ;;
*) return ;;
esac

# ── Starship prompt ─────────────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
	eval "$(starship init bash)"
fi

# ── Mise (tool version manager) ─────────────────────────────────────────────
if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate bash)"
fi

# ── History ─────────────────────────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoredups:erasedups
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/bash/history"
mkdir -p "$(dirname "$HISTFILE")"
shopt -s histappend
shopt -s checkwinsize

# ── Bash completion ─────────────────────────────────────────────────────────
if [ -f /etc/bash_completion ]; then
	# shellcheck disable=SC1091
	. /etc/bash_completion
elif [ -f /usr/share/bash-completion/bash_completion ]; then
	# shellcheck disable=SC1091
	. /usr/share/bash-completion/bash_completion
elif [ -f /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
	# shellcheck disable=SC1091
	. /opt/homebrew/etc/profile.d/bash_completion.sh
fi

# ── PATH extras ─────────────────────────────────────────────────────────────
[ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
export PATH

# ── Aliases ─────────────────────────────────────────────────────────────────
if command -v gls >/dev/null 2>&1; then
	alias ls='gls --color=auto'
else
	alias ls='ls -G' 2>/dev/null || alias ls='ls --color=auto'
fi
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
