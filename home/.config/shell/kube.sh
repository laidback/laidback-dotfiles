# ~/.config/shell/kube.sh — kubectl helpers shared by bash and zsh
# shellcheck shell=sh

ktx() {
	if ! command -v gum >/dev/null 2>&1; then
		echo "ktx: gum not found; install gum to use interactive kubeconfig selection" >&2
		return 1
	fi

	if [ ! -d "$HOME/.kube" ]; then
		echo "ktx: $HOME/.kube not found" >&2
		return 1
	fi

	_ktx_file="$(find "$HOME/.kube" -maxdepth 1 -type f | sort | gum choose --header "Select kubeconfig" --)" || return 1
	[ -n "${_ktx_file:-}" ] || return 1

	export KUBECONFIG="$_ktx_file"
	echo "KUBECONFIG=$KUBECONFIG"
}

kns() {
	if ! command -v kubectl >/dev/null 2>&1; then
		echo "kns: kubectl not found" >&2
		return 1
	fi

	if ! command -v gum >/dev/null 2>&1; then
		echo "kns: gum not found; install gum to use interactive namespace selection" >&2
		return 1
	fi

	_kns_namespaces="$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')" || return 1
	[ -n "$_kns_namespaces" ] || {
		echo "kns: no namespaces returned" >&2
		return 1
	}

	_kns_ns="$(printf '%s\n' "$_kns_namespaces" | gum filter --placeholder "Select namespace")" || return 1
	[ -n "${_kns_ns:-}" ] || return 1

	kubectl config set-context --current --namespace="$_kns_ns"
}