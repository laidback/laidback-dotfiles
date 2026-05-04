#!/usr/bin/env bash
#MISE description="Quick project fingerprint (language, services, ports)"
#
# Detects:
#   - Languages from common project files (package.json, go.mod, pyproject.toml,
#     Cargo.toml, pom.xml, build.gradle*, Gemfile, mix.exs, composer.json, etc.).
#   - Service hints (Dockerfile, docker-compose*.y?ml, Procfile, k8s/, helm/).
#   - Declared ports (EXPOSE in Dockerfile, ports: in compose, common envs).
#
# Intentionally simple: regex + file presence. Designed to be extended later
# with deeper scanners (AST, dep graphs, infra parsing).
#
# Usage:
#   mise run fingerprint           # current directory
#   mise run fingerprint /path/to/repo
set -euo pipefail

_root="${1:-$PWD}"
if [ ! -d "$_root" ]; then
	printf 'fingerprint: not a directory: %s\n' "$_root" >&2
	exit 2
fi
_root="$(cd "$_root" && pwd -P)"

# ── Helpers ─────────────────────────────────────────────────────────────────
_have() { [ -e "$_root/$1" ]; }
_glob_any() {
	# returns 0 if any path matching the glob exists at repo root
	for p in "$_root"/$1; do
		[ -e "$p" ] && return 0
	done
	return 1
}

_languages=""
_services=""
_ports=""

_add_lang() { _languages="${_languages:+$_languages, }$1"; }
_add_svc() { _services="${_services:+$_services, }$1"; }
_add_port() { _ports="${_ports:+$_ports, }$1"; }

# ── Languages ───────────────────────────────────────────────────────────────
_have package.json && _add_lang "node"
_have go.mod && _add_lang "go"
_have Cargo.toml && _add_lang "rust"
_have pyproject.toml && _add_lang "python"
_have requirements.txt && _add_lang "python"
_have setup.py && _add_lang "python"
_have Gemfile && _add_lang "ruby"
_have mix.exs && _add_lang "elixir"
_have composer.json && _add_lang "php"
_have pom.xml && _add_lang "java(maven)"
_glob_any "build.gradle*" && _add_lang "java(gradle)"
_have CMakeLists.txt && _add_lang "c/c++"
_have Makefile && _add_lang "make"
_have mise.toml && _add_lang "mise"
_have flake.nix && _add_lang "nix"
_have .terraform-version && _add_lang "terraform"
_glob_any "*.tf" && _add_lang "terraform"

# ── Services ────────────────────────────────────────────────────────────────
_have Dockerfile && _add_svc "docker"
_glob_any "docker-compose*.y*ml" && _add_svc "compose"
_glob_any "compose*.y*ml" && _add_svc "compose"
_have Procfile && _add_svc "procfile"
_have k8s && _add_svc "k8s"
_have kubernetes && _add_svc "k8s"
_have helm && _add_svc "helm"
_glob_any "*.yaml" && [ -d "$_root/.github/workflows" ] && _add_svc "gh-actions"
_have .gitlab-ci.yml && _add_svc "gitlab-ci"
_have skaffold.yaml && _add_svc "skaffold"

# ── Ports ───────────────────────────────────────────────────────────────────
if [ -f "$_root/Dockerfile" ]; then
	# EXPOSE 8080 / EXPOSE 8080/tcp — collect first token after EXPOSE
	while IFS= read -r _p; do
		_add_port "$_p"
	done < <(awk 'toupper($1)=="EXPOSE"{for(i=2;i<=NF;i++) print $i}' "$_root/Dockerfile" | sed 's#/.*##' | sort -u)
fi

# Any docker-compose ports — naive grep on "- '8080:80'" or "8080:80"
for _f in "$_root"/docker-compose*.y*ml "$_root"/compose*.y*ml; do
	[ -e "$_f" ] || continue
	while IFS= read -r _p; do
		_add_port "$_p"
	done < <(grep -Eo '[0-9]+:[0-9]+' "$_f" 2>/dev/null | awk -F: '{print $1}' | sort -u)
done

# Common env-driven ports (.env / .env.example)
for _f in "$_root/.env" "$_root/.env.example"; do
	[ -f "$_f" ] || continue
	while IFS= read -r _p; do
		_add_port "$_p"
	done < <(grep -Ei '^[A-Z_]*PORT=([0-9]+)' "$_f" 2>/dev/null | sed -E 's/.*=([0-9]+).*/\1/' | sort -u)
done

# ── Output ──────────────────────────────────────────────────────────────────
printf '── fingerprint ──────────────────────────────────────────────────────\n'
printf '  root      %s\n' "$_root"
printf '  languages %s\n' "${_languages:-(none)}"
printf '  services  %s\n' "${_services:-(none)}"
printf '  ports     %s\n' "${_ports:-(none)}"
printf '─────────────────────────────────────────────────────────────────────\n'
