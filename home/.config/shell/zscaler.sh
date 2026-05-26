#!/usr/bin/env sh
# ================================================================
# .config/shell/zscaler.sh
# Zscaler TLS interception — trust the enterprise root CA
#
# Sets environment variables so that curl, git, Node/npm,
# Python/pip, AWS CLI, and other TLS-verifying tools trust the
# Zscaler root certificate alongside the system CA bundle.
#
# Sourced by interactive and login shells after env.sh.
# Safe to source multiple times (guarded by LAIDBACK_ZSCALER_SOURCED).
# Silent no-op when the certificate is not present (non-corporate machine).
# ================================================================

[ -n "${LAIDBACK_ZSCALER_SOURCED:-}" ] && return 0
LAIDBACK_ZSCALER_SOURCED=1

# ── Locate the Zscaler root certificate ──────────────────────────────────────
_zscaler_cert=""
for _candidate in \
	"${LAIDBACK_DOTFILES_ROOT:-}/ZscalerRootCA.pem" \
	"${LAIDBACK_CONFIG:-$HOME/.config/laidback}/certs/ZscalerRootCA.pem"
do
	[ -r "$_candidate" ] && { _zscaler_cert="$_candidate"; break; }
done
unset _candidate

if [ -z "$_zscaler_cert" ]; then
	unset _zscaler_cert
	return 0   # cert not present — non-corporate machine, skip silently
fi

# ── Build a combined CA bundle (system CAs + Zscaler) ────────────────────────
# Tools that replace the bundle (curl, git, pip, ...) need the full system
# trust store combined with the Zscaler cert.  Tools that extend it (Node.js)
# can use the Zscaler cert alone via NODE_EXTRA_CA_CERTS.
_combined="${LAIDBACK_CONFIG:-$HOME/.config/laidback}/certs/ca-bundle.pem"

if [ ! -f "$_combined" ] || [ "$_zscaler_cert" -nt "$_combined" ]; then
	_system_bundle=""
	for _candidate in \
		/etc/ssl/cert.pem \
		/etc/ssl/certs/ca-certificates.crt \
		/etc/pki/tls/certs/ca-bundle.crt \
		/opt/homebrew/etc/openssl@3/cert.pem \
		/usr/local/etc/openssl@3/cert.pem \
		/usr/local/etc/openssl/cert.pem
	do
		[ -r "$_candidate" ] && { _system_bundle="$_candidate"; break; }
	done
	unset _candidate

	if [ -n "$_system_bundle" ]; then
		mkdir -p "$(dirname "$_combined")"
		cat "$_system_bundle" "$_zscaler_cert" > "$_combined"
	fi
	unset _system_bundle
fi

# Prefer the combined bundle; fall back to the Zscaler cert alone.
if [ -f "$_combined" ]; then
	_ca_bundle="$_combined"
else
	_ca_bundle="$_zscaler_cert"
fi

# ── Node.js / npm / npx ──────────────────────────────────────────────────────
# NODE_EXTRA_CA_CERTS is additive — safe to point at the Zscaler cert alone.
NODE_EXTRA_CA_CERTS="$_zscaler_cert"
export NODE_EXTRA_CA_CERTS

# ── curl / libcurl-backed tools ───────────────────────────────────────────────
CURL_CA_BUNDLE="$_ca_bundle"
export CURL_CA_BUNDLE

# ── Git ───────────────────────────────────────────────────────────────────────
GIT_SSL_CAINFO="$_ca_bundle"
export GIT_SSL_CAINFO

# ── Python requests / pip / pipenv / poetry / uv ─────────────────────────────
REQUESTS_CA_BUNDLE="$_ca_bundle"
export REQUESTS_CA_BUNDLE

# ── OpenSSL-backed CLIs (Ruby gems, wget, misc) ───────────────────────────────
SSL_CERT_FILE="$_ca_bundle"
export SSL_CERT_FILE

# ── AWS CLI ───────────────────────────────────────────────────────────────────
AWS_CA_BUNDLE="$_ca_bundle"
export AWS_CA_BUNDLE

unset _ca_bundle _combined _zscaler_cert
