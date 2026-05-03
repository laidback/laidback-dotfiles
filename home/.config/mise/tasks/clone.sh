#!/usr/bin/env bash
# @description: Clone a git URL into $XDG_PROJECTS_DIR/<forge>/<group>/<project>
# @arg url "Git URL to clone (https://, git@, or ssh://)"
#
# Available system-wide as `mise run clone <url>` after dotfiles bootstrap.
# Layout is deterministic per the laidback forge convention:
#
#   mise run clone https://github.com/laidback/laidback-system
#     → $XDG_PROJECTS_DIR/github.com/laidback/laidback-system
#
#   mise run clone git@gitlab.com:laidback/gitops-bootstrap.git
#     → $XDG_PROJECTS_DIR/gitlab.com/laidback/gitops-bootstrap
set -euo pipefail

: "${XDG_PROJECTS_DIR:=$HOME/projects}"

_url="${1:-}"
if [ -z "$_url" ]; then
    printf 'usage: mise run clone <git-url>\n' >&2
    exit 2
fi

_path="$(printf '%s' "$_url" \
    | sed -E 's#^(https?://|ssh://git@|git@)##' \
    | sed -E 's#:#/#' \
    | sed -E 's#\.git$##')"

_target="$XDG_PROJECTS_DIR/$_path"

if [ -d "$_target/.git" ]; then
    printf 'clone: already at %s — pulling\n' "$_target"
    git -C "$_target" pull --ff-only
    exit $?
fi

mkdir -p "$(dirname "$_target")"
git clone "$_url" "$_target"
printf 'clone: %s\n' "$_target"
