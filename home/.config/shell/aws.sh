# ~/.config/shell/aws.sh — AWS helpers shared by bash and zsh
# shellcheck shell=sh

acuc() {
	if ! command -v gum >/dev/null 2>&1; then
		echo "acuc: gum not found; install gum to use interactive profile selection" >&2
		return 1
	fi

	if [ ! -f "$HOME/.aws/config" ]; then
		echo "acuc: $HOME/.aws/config not found" >&2
		return 1
	fi

	_acuc_profile="$(grep -E '^\[profile |\[default\]' "$HOME/.aws/config" \
		| sed 's/^\[profile //;s/^\[default\]/default/;s/\]$//' \
		| sort | gum choose --header "Select AWS profile" --)" || return 1
	[ -n "${_acuc_profile:-}" ] || return 1

	export AWS_PROFILE="$_acuc_profile"
	echo "AWS_PROFILE=$AWS_PROFILE"
}
