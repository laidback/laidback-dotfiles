#!/usr/bin/env bash
#MISE description="Project fingerprint: forge, CI, mise, languages, tooling matrix"
#
# Reports yes/no for first-class project citizens and a tooling-coverage
# matrix so we can standardise tools (shfmt, shellcheck, prettier, ...) across
# repositories.
#
# Usage:
#   mise run projects:fingerprint           # current directory
#   mise run projects:fingerprint /path     # explicit root
set -euo pipefail

# mise may change cwd; honour the user's invocation directory first.
_root="${1:-${MISE_ORIGINAL_CWD:-${MISE_PROJECT_ROOT:-$PWD}}}"
[ -d "$_root" ] || {
	printf 'fingerprint: not a directory: %s\n' "$_root" >&2
	exit 2
}
_root="$(cd "$_root" && pwd -P)"

# ── helpers ────────────────────────────────────────────────────────────────
_have() { [ -e "$_root/$1" ]; }
_have_any() {
	for _p in "$@"; do _have "$_p" && return 0; done
	return 1
}
_glob_any() {
	# shellcheck disable=SC2231 # intentional unquoted glob
	for _p in "$_root"/$1; do [ -e "$_p" ] && return 0; done
	return 1
}
_yn() { if "$@"; then printf 'yes'; else printf 'no '; fi; }

_section() {
	printf '\n  %s\n' "$1"
	printf '  %s\n' "──────────────────────────────────────────────"
}
_kv() { printf '  %-14s %s\n' "$1" "$2"; }
_matrix() {
	# _matrix label yes|no [hint]
	printf '  %-14s %-3s  %s\n' "$1" "$2" "${3:-}"
}

# ── header ─────────────────────────────────────────────────────────────────
printf '── fingerprint ────────────────────────────────────────────────\n'
_kv "root" "$_root"
_kv "rel" "${_root/#$HOME/~}"

# ── forge ──────────────────────────────────────────────────────────────────
_section "forge"
_remote=""
_provider="(no git remote)"
_owner="-"
_repo="-"
_branch="-"
_default_branch="-"
if _have .git; then
	_branch="$(git -C "$_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
	_remote="$(git -C "$_root" config --get remote.origin.url 2>/dev/null || true)"
	_default_branch="$(git -C "$_root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo '-')"
	if [ -n "$_remote" ]; then
		# normalise  git@host:owner/repo(.git)?  →  https-style host/owner/repo
		_norm="$(printf '%s\n' "$_remote" | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')"
		_provider="$(printf '%s\n' "$_norm" | sed -E 's#^https?://##' | awk -F/ '{print $1}')"
		# owner = everything between provider and last segment (handles gitlab subgroups)
		_owner="$(printf '%s\n' "$_norm" | sed -E 's#^https?://[^/]+/##; s#/[^/]+$##')"
		_repo="$(printf '%s\n' "$_norm" | awk -F/ '{print $NF}')"
	fi
fi
_kv "provider" "$_provider"
_kv "owner/group" "$_owner"
_kv "project" "$_repo"
_kv "branch" "$_branch"
_kv "default br." "$_default_branch"

# ── ci ─────────────────────────────────────────────────────────────────────
_section "ci"
_gh_count=0
if [ -d "$_root/.github/workflows" ]; then
	_gh_count="$(find "$_root/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ')"
fi
_gh_hint=""
[ "$_gh_count" -gt 0 ] && _gh_hint="$_gh_count workflow(s)"
_matrix "github" "$([ "$_gh_count" -gt 0 ] && echo yes || echo 'no ')" "$_gh_hint"
_matrix "gitlab" "$(_yn _have .gitlab-ci.yml)"
_matrix "circleci" "$(_yn _have .circleci/config.yml)"
_matrix "jenkins" "$(_yn _have_any Jenkinsfile jenkinsfile)"
_matrix "buildkite" "$(_yn _have .buildkite/pipeline.yml)"
_matrix "drone" "$(_yn _have .drone.yml)"
_matrix "azure" "$(_yn _have_any azure-pipelines.yml .azure-pipelines.yml)"

# ── mise ───────────────────────────────────────────────────────────────────
_section "mise"
_mise_file=""
for _f in mise.toml .mise.toml mise/config.toml .mise/config.toml; do
	if _have "$_f"; then
		_mise_file="$_f"
		break
	fi
done
_matrix "mise" "$([ -n "$_mise_file" ] && echo yes || echo 'no ')" "${_mise_file:-}"
if [ -n "$_mise_file" ] && command -v mise >/dev/null 2>&1; then
	_tools_n="$( (cd "$_root" && mise ls --current 2>/dev/null) | awk 'NF>0' | wc -l | tr -d ' ' || echo 0)"
	_tasks_n="$( (cd "$_root" && mise tasks --no-header 2>/dev/null) | wc -l | tr -d ' ' || echo 0)"
	_kv "tools" "$_tools_n"
	_kv "tasks" "$_tasks_n"
fi

# ── languages ──────────────────────────────────────────────────────────────
_section "languages"
_languages=""
_add_lang() { _languages="${_languages:+$_languages, }$1"; }
_have package.json && _add_lang "node"
_have go.mod && _add_lang "go"
_have Cargo.toml && _add_lang "rust"
_have_any pyproject.toml requirements.txt setup.py && _add_lang "python"
_have Gemfile && _add_lang "ruby"
_have mix.exs && _add_lang "elixir"
_have composer.json && _add_lang "php"
_have pom.xml && _add_lang "java(maven)"
_glob_any "build.gradle*" && _add_lang "java(gradle)"
_have CMakeLists.txt && _add_lang "c/c++"
_have flake.nix && _add_lang "nix"
{ _have .terraform-version || _glob_any "*.tf"; } && _add_lang "terraform"
_glob_any "*.sh" && _add_lang "shell"
_kv "detected" "${_languages:-(none)}"

# ── tooling matrix ─────────────────────────────────────────────────────────
_section "tooling matrix"

# Files we'll grep for tool names when there is no canonical config file.
_search_files=(.pre-commit-config.yaml mise.toml .mise.toml mise/config.toml Makefile)
_workflow_files=()
if [ -d "$_root/.github/workflows" ]; then
	while IFS= read -r _wf; do
		_workflow_files+=("${_wf#"$_root"/}")
	done < <(find "$_root/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)
fi

_mentioned() {
	# _mentioned <token>
	local _tok="$1"
	for _f in "${_search_files[@]}" "${_workflow_files[@]}"; do
		[ -f "$_root/$_f" ] || continue
		grep -Fq "$_tok" "$_root/$_f" 2>/dev/null && return 0
	done
	return 1
}

# _check_tool <label> [config-glob ...] [-- <token>]
#   yes if any config-glob matches; otherwise yes if <token> is mentioned in
#   pre-commit / mise / Makefile / GH workflows; otherwise no.
_check_tool() {
	local _label="$1"
	shift
	local _configs=()
	local _token=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--)
			shift
			_token="$1"
			break
			;;
		*)
			_configs+=("$1")
			shift
			;;
		esac
	done
	local _hit=""
	for _g in "${_configs[@]}"; do
		if _glob_any "$_g"; then
			_hit="$_g"
			break
		fi
	done
	if [ -n "$_hit" ]; then
		_matrix "$_label" "yes" "$_hit"
		return
	fi
	if [ -n "$_token" ] && _mentioned "$_token"; then
		_matrix "$_label" "yes" "(referenced)"
		return
	fi
	_matrix "$_label" "no "
}

_check_tool "shellcheck" ".shellcheckrc" -- "shellcheck"
_check_tool "shfmt" -- "shfmt"
_check_tool "prettier" ".prettierrc*" "prettier.config.*" -- "prettier"
_check_tool "eslint" ".eslintrc*" "eslint.config.*" -- "eslint"
_check_tool "markdownlint" ".markdownlint.json" ".markdownlint.yaml" ".markdownlintrc" -- "markdownlint"
_check_tool "yamllint" ".yamllint" ".yamllint.yml" ".yamllint.yaml" -- "yamllint"
_check_tool "actionlint" -- "actionlint"
_check_tool "editorconfig" ".editorconfig"
_check_tool "pre-commit" ".pre-commit-config.yaml"
_check_tool "golangci-lint" ".golangci.yml" ".golangci.yaml" ".golangci.toml" -- "golangci-lint"
_check_tool "gofmt" -- "gofmt"
_check_tool "ruff" "ruff.toml" ".ruff.toml" -- "ruff"
_check_tool "black" -- "black"
_check_tool "mypy" "mypy.ini" ".mypy.ini" -- "mypy"
_check_tool "rustfmt" "rustfmt.toml" ".rustfmt.toml"
_check_tool "clippy" ".clippy.toml" "clippy.toml"
_check_tool "hadolint" ".hadolint.yaml" ".hadolint.yml" -- "hadolint"
_check_tool "renovate" "renovate.json" ".renovaterc.json" ".renovaterc"
_check_tool "dependabot" ".github/dependabot.yml" ".github/dependabot.yaml"

# ── services / ports ───────────────────────────────────────────────────────
_section "services & ports"
_services=""
_add_svc() { _services="${_services:+$_services, }$1"; }
_have Dockerfile && _add_svc "docker"
_glob_any "docker-compose*.y*ml" && _add_svc "compose"
_glob_any "compose*.y*ml" && _add_svc "compose"
_have Procfile && _add_svc "procfile"
_have_any k8s kubernetes && _add_svc "k8s"
_have helm && _add_svc "helm"
_have skaffold.yaml && _add_svc "skaffold"
_kv "services" "${_services:-(none)}"

_ports=""
_add_port() { _ports="${_ports:+$_ports, }$1"; }
if [ -f "$_root/Dockerfile" ]; then
	while IFS= read -r _p; do _add_port "$_p"; done \
		< <(awk 'toupper($1)=="EXPOSE"{for(i=2;i<=NF;i++) print $i}' "$_root/Dockerfile" |
			sed 's#/.*##' | sort -u)
fi
for _f in "$_root"/docker-compose*.y*ml "$_root"/compose*.y*ml; do
	[ -e "$_f" ] || continue
	while IFS= read -r _p; do _add_port "$_p"; done \
		< <(grep -Eo '[0-9]+:[0-9]+' "$_f" 2>/dev/null | awk -F: '{print $1}' | sort -u)
done
_kv "ports" "${_ports:-(none)}"

printf '\n── end ────────────────────────────────────────────────────────\n'
