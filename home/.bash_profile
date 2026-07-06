# ~/.bash_profile — Login bash entrypoint
# shellcheck shell=bash
# Source ~/.bashrc for interactive login shells.
# shellcheck source=.bashrc
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

complete -C /Users/ciszluk/.local/share/mise/installs/terraform/1.14.7/terraform terraform
