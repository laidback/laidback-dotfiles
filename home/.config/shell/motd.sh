#!/usr/bin/env sh
# ~/.config/shell/motd.sh
# Mode-aware MOTD for non-interactive contexts (ai/ci).
#
# Behaviour:
#   - In human mode: silent. The interactive shell indicator is provided by
#     the starship `shell` and `shlvl` modules (see ~/.config/starship.toml).
#   - In ai/ci mode: prints one short line per (shell, mode, dir) tuple
#     change. State cached in $XDG_STATE_HOME/laidback/motd_last.
#   - Disabled with LAIDBACK_MOTD=0. Forced with LAIDBACK_FORCE_MOTD=1
#     (bypasses the human-mode short-circuit too — useful for testing).
#
# Hook from .zshrc:
#   add-zsh-hook chpwd  _laidback_motd
#   add-zsh-hook precmd _laidback_motd
#
# Hook from .bashrc:
#   PROMPT_COMMAND="__laidback_motd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Disabled outright.
[ "${LAIDBACK_MOTD:-1}" = "0" ] && return 0

_mode="${LAIDBACK_EXECUTION_MODE:-human}"

# Human mode: starship handles the shell indicator. Stay silent unless the
# caller explicitly forces output (LAIDBACK_FORCE_MOTD=1).
if [ "$_mode" = "human" ] && [ "${LAIDBACK_FORCE_MOTD:-0}" != "1" ]; then
	unset _mode
	return 0
fi

# Only show in interactive shells unless explicitly forced. (ai/ci usage
# typically runs without PS1, so this is also gated by FORCE.)
if [ -z "${PS1:-}" ] && [ "${LAIDBACK_FORCE_MOTD:-0}" != "1" ]; then
	unset _mode
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

# Tag combines mode and shell, e.g. [ai bash] / [ci zsh] / [bash] (forced).
case "$_mode" in
human) _tag="$_shell" ;;
*) _tag="$_mode $_shell" ;;
esac

# Single-line, machine-friendly output. Same format for ai/ci/forced-human.
printf '[%s] %s%s\n' "$_tag" "$_dir" "${_git:+ git=$_git}"

unset _shell _mode _dir _state_file _key _last _git _tag
