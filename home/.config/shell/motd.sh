#!/usr/bin/env sh
# ~/.config/shell/motd.sh
# Shell-, directory-, and mode-aware MOTD.
#
# Behaviour:
#   - Silent unless the (shell, mode, directory) tuple differs from the
#     last-shown one (cached in $XDG_STATE_HOME/laidback/motd_last).
#   - One short line per context switch — including switching shells in the
#     same directory (typing `bash` from zsh now prints a visible signal).
#   - Mode-aware via $LAIDBACK_EXECUTION_MODE (human|ai|ci). Default: human.
#   - Disabled with LAIDBACK_MOTD=0. Forced with LAIDBACK_FORCE_MOTD=1.
#
# Hook from .zshrc:
#   add-zsh-hook chpwd  _laidback_motd
#   add-zsh-hook precmd _laidback_motd
#
# Hook from .bashrc:
#   PROMPT_COMMAND="__laidback_motd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Disabled outright.
[ "${LAIDBACK_MOTD:-1}" = "0" ] && return 0

# Only show in interactive shells unless explicitly forced.
if [ -z "${PS1:-}" ] && [ "${LAIDBACK_FORCE_MOTD:-0}" != "1" ]; then
	return 0
fi

# Detect the running shell. BASH_VERSION/ZSH_VERSION are the most reliable
# signals; fall back to $0 for anything exotic.
if [ -n "${BASH_VERSION:-}" ]; then
	_shell="bash"
elif [ -n "${ZSH_VERSION:-}" ]; then
	_shell="zsh"
else
	_shell="$(basename "${0##-}" 2>/dev/null || echo sh)"
fi

_mode="${LAIDBACK_EXECUTION_MODE:-human}"
_dir="$(pwd -P 2>/dev/null || echo '?')"
_state_file="${XDG_STATE_HOME:-$HOME/.local/state}/laidback/motd_last"
_key="${_shell}|${_mode}|${_dir}"

_last=""
[ -f "$_state_file" ] && _last="$(cat "$_state_file" 2>/dev/null)"

# Same shell+mode+dir as last shown — stay silent.
if [ "$_key" = "$_last" ]; then
	unset _shell _mode _dir _state_file _key _last
	return 0
fi

# Update cache (best-effort; never error out the prompt).
mkdir -p "$(dirname "$_state_file")" 2>/dev/null || true
printf '%s' "$_key" >"$_state_file" 2>/dev/null || true

# Optional git branch.
_git=""
if command -v git >/dev/null 2>&1; then
	_git="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

# Tag combines mode (when non-human) and shell, e.g. [bash] / [ai bash] / [ci zsh].
case "$_mode" in
human) _tag="$_shell" ;;
*) _tag="$_mode $_shell" ;;
esac

case "$_mode" in
ai | ci)
	# Single-line, machine-friendly.
	printf '[%s] %s%s\n' "$_tag" "$_dir" "${_git:+ git=$_git}"
	;;
*)
	# Human: [shell] user@host:dir [branch]
	_user="$(id -un 2>/dev/null || echo "$USER")"
	_host="$(hostname -s 2>/dev/null || hostname)"
	printf '[%s] %s@%s:%s%s\n' "$_tag" "$_user" "$_host" "$_dir" "${_git:+ [$_git]}"
	unset _user _host
	;;
esac

unset _shell _mode _dir _state_file _key _last _git _tag
