#!/usr/bin/env bash
# @description: Show dotfiles status (available system-wide after bootstrap)
set -euo pipefail

: "${LAIDBACK_FORGE:=github.com/laidback}"
: "${XDG_PROJECTS_DIR:=$HOME/projects}"
: "${LAIDBACK_DOTFILES_ROOT:=$XDG_PROJECTS_DIR/$LAIDBACK_FORGE/laidback-dotfiles}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"

_sym() {
	local label="$1" path="$2"
	if [ -L "$path" ]; then
		printf "  %-22s symlink → %s\n" "$label" "$(readlink "$path")"
	elif [ -e "$path" ]; then
		printf "  %-22s plain   %s\n" "$label" "$path"
	else
		printf "  %-22s MISSING %s\n" "$label" "$path"
	fi
}

echo "======================================================================"
echo "  laidback-dotfiles  status"
echo "======================================================================"
echo ""

echo "  environment"
printf "  %-22s %s\n" "HOME" "$HOME"
printf "  %-22s %s\n" "XDG_PROJECTS_DIR" "$XDG_PROJECTS_DIR"
printf "  %-22s %s\n" "LAIDBACK_FORGE" "$LAIDBACK_FORGE"
printf "  %-22s %s\n" "LAIDBACK_DOTFILES_ROOT" "$LAIDBACK_DOTFILES_ROOT"
for _v in LAIDBACK_SYSTEM_ROOT LAIDBACK_CLOUD_ROOT LAIDBACK_PLATFORM_ROOT LAIDBACK_WORKLOADS_ROOT LAIDBACK_APPS_ROOT; do
	_val="$(eval "printf '%s' \"\${$_v:-}\"")"
	[ -n "$_val" ] && printf "  %-22s %s\n" "$_v" "$_val"
done
printf "  %-22s %s\n" "XDG_CONFIG_HOME" "$XDG_CONFIG_HOME"
printf "  %-22s %s\n" "XDG_DATA_HOME" "$XDG_DATA_HOME"
printf "  %-22s %s\n" "XDG_STATE_HOME" "$XDG_STATE_HOME"
printf "  %-22s %s\n" "XDG_CACHE_HOME" "$XDG_CACHE_HOME"
echo ""

echo "  repository"
if [ -d "$LAIDBACK_DOTFILES_ROOT/.git" ]; then
	_branch="$(git -C "$LAIDBACK_DOTFILES_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
	_commit="$(git -C "$LAIDBACK_DOTFILES_ROOT" log -1 --format='%h %s' 2>/dev/null || echo unknown)"
	printf "  %-22s %s\n" "branch" "$_branch"
	printf "  %-22s %s\n" "commit" "$_commit"
else
	printf "  %-22s %s\n" "dotfiles" "NOT FOUND at $LAIDBACK_DOTFILES_ROOT"
fi
echo ""

echo "  stow symlinks"
_sym "env.sh" "$HOME/.config/shell/env.sh"
_sym "mise config" "$HOME/.config/mise/config.toml"
_sym ".zshrc" "$HOME/.zshrc"
_sym ".zprofile" "$HOME/.zprofile"
_sym ".profile" "$HOME/.profile"
_sym "git/config" "$HOME/.config/git/config"
_sym "git/ignore" "$HOME/.config/git/ignore"
_sym "git/work.config" "$HOME/.config/git/work.config"
_sym "git/attributes" "$HOME/.config/git/attributes"
echo ""

_file() {
	local label="$1" path="$2"
	if [ -x "$path" ]; then
		printf "  %-22s installed  %s\n" "$label" "$path"
	elif [ -e "$path" ]; then
		printf "  %-22s present    %s\n" "$label" "$path"
	else
		printf "  %-22s MISSING    %s\n" "$label" "$path"
	fi
}

echo "  global tasks"
_file "dotfiles:status" "$HOME/.config/mise/tasks/dotfiles/status.sh"
_file "dotfiles:doctor" "$HOME/.config/mise/tasks/dotfiles/doctor.sh"
echo ""

echo "  tools"
for _tool in mise git stow vim delta kubectl gh jq sops age; do
	if command -v "$_tool" >/dev/null 2>&1; then
		_ver_raw="$("$_tool" --version 2>/dev/null || true)"
		_ver="$(printf '%s' "$_ver_raw" | head -1)"
		[ -z "$_ver" ] && _ver="installed (version unavailable)"
		printf "  %-22s %s\n" "$_tool" "$_ver"
	else
		printf "  %-22s %s\n" "$_tool" "not found"
	fi
done

echo "======================================================================"
