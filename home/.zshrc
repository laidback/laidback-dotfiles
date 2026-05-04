# ~/.zshrc — Interactive zsh configuration
# Sourced for every interactive zsh session.

# ── Environment foundation ──────────────────────────────────────────────────
# shellcheck source=.config/shell/env.sh
. "$HOME/.config/shell/env.sh"

# Return early in non-interactive shells (should not happen via .zshrc, but guard anyway).
[[ -o interactive ]] || return

# ── Zinit ───────────────────────────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"

    # OMZ snippets (git aliases, directory helpers, kube + zoxide integration)
    zinit snippet OMZL::git.zsh
    zinit snippet OMZL::directories.zsh
    zinit snippet OMZP::git
    zinit snippet OMZP::kubectl
    zinit snippet OMZP::kube-ps1
    zinit snippet OMZP::zoxide

    # Core plugins — loaded asynchronously after first prompt
    zinit wait lucid for \
        atinit"zicompinit; zicdreplay" \
            zdharma-continuum/fast-syntax-highlighting \
        blockf \
            zsh-users/zsh-completions \
        atload"!_zsh_autosuggest_start" \
            zsh-users/zsh-autosuggestions
fi

# ── Starship prompt ─────────────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# ── Mise (tool version manager) ─────────────────────────────────────────────
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

# ── zsh options ─────────────────────────────────────────────────────────────
setopt promptsubst extendedglob

# History
HISTSIZE=50000
SAVEHIST=50000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"
setopt share_history append_history hist_ignore_dups hist_reduce_blanks

# Completion
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ── PATH extras ─────────────────────────────────────────────────────────────
[[ -d "$HOME/bin" ]]        && PATH="$HOME/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"
export PATH

# ── Aliases ──────────────────────────────────────────────────────────────────
# ls: prefer GNU coreutils on macOS if available, fall back to native
if command -v gls >/dev/null 2>&1; then
    alias ls='gls --color=auto'
else
    alias ls='ls -G'
fi
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'

# ── MOTD (directory-aware, mode-aware) ──────────────────────────────────────
# Silent unless cwd changed since last shown.
if [ -f "$HOME/.config/shell/motd.sh" ]; then
    autoload -U add-zsh-hook 2>/dev/null
    _laidback_motd() { . "$HOME/.config/shell/motd.sh"; }
    if typeset -f add-zsh-hook >/dev/null 2>&1; then
        add-zsh-hook chpwd  _laidback_motd
        add-zsh-hook precmd _laidback_motd
    fi
fi
