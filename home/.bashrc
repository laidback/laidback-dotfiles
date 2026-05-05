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
# starship needs bash 4+. macOS ships /bin/bash 3.2 — skip silently there.
# To get a modern bash on macOS:  brew install bash  (or use a mise plugin).
if command -v starship >/dev/null 2>&1 &&
	[ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
	eval "$(starship init bash)"
fi

# ── Mise (tool version manager) ─────────────────────────────────────────────
# `mise activate bash` uses bash 4+ features in its prompt hooks. Fall back to
# shims-only mode on bash 3.2 so the shell still works (matches .bashrc.ai).
if command -v mise >/dev/null 2>&1; then
	if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
		eval "$(mise activate bash)"
	else
		eval "$(mise activate bash --shims)"
	fi
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

# Shared kubectl helpers (ktx, kns)
[ -f "$HOME/.config/shell/kube.sh" ] && . "$HOME/.config/shell/kube.sh"

# ── MOTD (directory-aware, mode-aware) ──────────────────────────────────────
# Silent unless cwd changed since last shown.
if [ -f "$HOME/.config/shell/motd.sh" ]; then
	__laidback_motd() { . "$HOME/.config/shell/motd.sh"; }
	case ";${PROMPT_COMMAND:-};" in
	*";__laidback_motd;"*) ;;
	*) PROMPT_COMMAND="__laidback_motd${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
	esac
fi
