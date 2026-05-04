#!/usr/bin/env sh
# ~/.config/shell/motd.sh
# Directory-aware, mode-aware MOTD.
#
# Behaviour:
#   - Silent unless the current directory differs from the last-shown one
#     (cached in $XDG_STATE_HOME/laidback/motd_last_dir).
#   - One short line per context switch.
#   - Mode-aware via $LAIDBACK_EXECUTION_MODE (human|ai|ci). Default: human.
#   - Disabled with LAIDBACK_MOTD=0. Forced with LAIDBACK_FORCE_MOTD=1.
#
# Hook from .zshrc:
#   add-zsh-hook chpwd  motd_precmd
#   add-zsh-hook precmd motd_precmd
#
# Hook from .bashrc:
#   PROMPT_COMMAND="__motd_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Disabled outright.
[ "${LAIDBACK_MOTD:-1}" = "0" ] && return 0

# Only show in interactive shells unless explicitly forced.
if [ -z "${PS1:-}" ] && [ "${LAIDBACK_FORCE_MOTD:-0}" != "1" ]; then
	return 0
fi

_mode="${LAIDBACK_EXECUTION_MODE:-human}"
_dir="$(pwd -P 2>/dev/null || echo '?')"
_state_file="${XDG_STATE_HOME:-$HOME/.local/state}/laidback/motd_last_dir"

_last_dir=""
[ -f "$_state_file" ] && _last_dir="$(cat "$_state_file" 2>/dev/null)"

# Same directory as last shown — stay silent.
if [ "$_dir" = "$_last_dir" ]; then
	unset _mode _dir _state_file _last_dir
	return 0
fi

# Update cache (best-effort; never error out the prompt).
mkdir -p "$(dirname "$_state_file")" 2>/dev/null || true
printf '%s' "$_dir" >"$_state_file" 2>/dev/null || true

# Optional git branch.
_git=""
if command -v git >/dev/null 2>&1; then
	_git="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

case "$_mode" in
ai)
	# Single-line, machine-friendly.
	printf '[ai] %s%s\n' "$_dir" "${_git:+ git=$_git}"
	;;
ci)
	printf '[ci] %s%s\n' "$_dir" "${_git:+ git=$_git}"
	;;
*)
	# Human: user@host:dir [branch]
	_user="$(id -un 2>/dev/null || echo "$USER")"
	_host="$(hostname -s 2>/dev/null || hostname)"
	printf '%s@%s:%s%s\n' "$_user" "$_host" "$_dir" "${_git:+ [$_git]}"
	unset _user _host
	;;
esac

unset _mode _dir _state_file _last_dir _git
