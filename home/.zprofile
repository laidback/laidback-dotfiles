# ~/.zprofile — zsh login shell configuration
# Sourced once on login (before .zshrc for interactive login shells).
# shellcheck shell=bash

# shellcheck source=.config/shell/env.sh
. "$HOME/.config/shell/env.sh"

# kubectl shell completion (optional — only if the file exists)
if [ -f "$HOME/.config/laidback/shell/kubectl.zsh.sh" ]; then
	# shellcheck disable=SC1090
	. "$HOME/.config/laidback/shell/kubectl.zsh.sh"
fi
