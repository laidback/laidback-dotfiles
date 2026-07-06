#!/usr/bin/env bash
set -euo pipefail

_task="${1:-}"
if [ -z "$_task" ]; then
  echo "usage: $0 <task-name>" >&2
  exit 1
fi

run_bootstrap() {
  _ensure_homebrew() {
    if [ "$(uname -s)" != "Darwin" ]; then
      return 0
    fi

    if [ -x /opt/homebrew/bin/brew ] && ! command -v brew >/dev/null 2>&1; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ] && ! command -v brew >/dev/null 2>&1; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew >/dev/null 2>&1; then
      return 0
    fi

    echo "bootstrap: Homebrew not found — installing..."
    if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      echo "bootstrap: Homebrew install failed — install manually and re-run" >&2
      exit 1
    fi

    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! command -v brew >/dev/null 2>&1; then
      echo "bootstrap: Homebrew installed but brew is still not in PATH" >&2
      exit 1
    fi
  }

  _ensure_brew_formula() {
    local formula="$1"
    if brew list --formula "$formula" >/dev/null 2>&1; then
      return 0
    fi
    echo "bootstrap: installing $formula via Homebrew..."
    brew install "$formula"
  }

  # Ensure stow is available (not in mise registry — install via system package manager)
  if ! command -v stow >/dev/null 2>&1; then
    echo "bootstrap: installing stow..."
    case "$(uname -s)" in
      Darwin)
        _ensure_homebrew
        if ! brew install stow; then
          echo "bootstrap: failed to install stow with Homebrew" >&2
          exit 1
        fi
        ;;
      Linux)
        if command -v apt-get >/dev/null 2>&1; then
          sudo apt-get install -y stow
        elif command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y stow
        else
          echo "bootstrap: cannot install stow — install it manually and re-run" >&2
          exit 1
        fi
        ;;
      *)
        echo "bootstrap: unsupported OS for stow auto-install" >&2
        exit 1
        ;;
    esac
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    _ensure_homebrew
    _ensure_brew_formula stow
    _ensure_brew_formula starship
    _ensure_brew_formula markdownlint-cli
    _ensure_brew_formula bash
  fi

  mkdir -p "$HOME/.kube" "$HOME/.aws" "$HOME/.config/Code/User"
  mkdir -p "${XDG_PROJECTS_DIR:-$HOME/projects}"

  _xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  _unfold() {
    local _dir="$1"
    if [ -L "$_dir" ]; then
      echo "bootstrap: un-folding stow-folded $_dir -> real directory"
      local _real
      _real="$(readlink -f "$_dir" 2>/dev/null || readlink "$_dir")"
      rm "$_dir"
      mkdir -p "$_dir"
      if [ -d "$_real" ] && [ "$_real" != "$_dir" ]; then
        for _f in "$_real"/.sops.yaml "$_real"/secrets.env.sops "$_real"/keys.txt; do
          if [ -f "$_f" ] && [ ! -e "$_dir/$(basename "$_f")" ]; then
            mv "$_f" "$_dir/"
          fi
        done
      fi
    fi
    mkdir -p "$_dir"
  }

  _unfold "$_xdg_config/laidback"
  _unfold "$_xdg_config/sops/age"
  chmod 700 "$_xdg_config/sops/age" 2>/dev/null || true

  stow --dir="$(pwd)" --target="$HOME" --adopt --restow home
  echo "bootstrap: home/ stowed into $HOME"
  git restore home >/dev/null 2>&1 || true

  if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    _gitcfg_bak="$HOME/.gitconfig.pre-laidback"
    echo "bootstrap: moving $HOME/.gitconfig -> $_gitcfg_bak (XDG config takes over)"
    mv "$HOME/.gitconfig" "$_gitcfg_bak"
  fi

  if command -v vim >/dev/null 2>&1; then
    _plug="$HOME/.vim/autoload/plug.vim"
    if [ ! -f "$_plug" ]; then
      echo "bootstrap: installing vim-plug..."
      curl -fLo "$_plug" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
        && echo "bootstrap: vim-plug installed at $_plug" \
        || echo "bootstrap: vim-plug install failed - run :PlugInstall inside vim"
    else
      echo "bootstrap: vim-plug already present — skipping download"
    fi
    if [ -f "$_plug" ]; then
      echo "bootstrap: installing vim plugins (PlugInstall)..."
      vim -E -s -u "$HOME/.vimrc" +PlugInstall +qall 2>/dev/null || true
      _plug_count="$(find "$HOME/.vim/plugged" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | xargs)"
      if [ "${_plug_count:-0}" -gt 0 ]; then
        echo "bootstrap: vim plugins installed ($_plug_count plugins in ~/.vim/plugged/)"
      else
        echo "bootstrap: vim plugins may not have installed — open vim and run :PlugInstall"
      fi
    fi
  else
    echo "bootstrap: vim not found — skipping vim-plug setup"
  fi

  _kvs_bin="$HOME/.local/bin/kubectl-view_secret"
  _kvs_ver="0.16.0"
  if [ -f "$_kvs_bin" ]; then
    echo "bootstrap: kubectl-view_secret already present — skipping"
  else
    _kvs_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    _kvs_arch="$(uname -m)"
    case "$_kvs_arch" in
      x86_64) _kvs_arch="amd64" ;;
      aarch64|arm64) _kvs_arch="arm64" ;;
      *) echo "bootstrap: kubectl-view-secret — unsupported arch $_kvs_arch, skipping" ;;
    esac
    _kvs_url="https://github.com/elsesiy/kubectl-view-secret/releases/download/v${_kvs_ver}/kubectl-view-secret_v${_kvs_ver}_${_kvs_os}_${_kvs_arch}.tar.gz"
    _kvs_tmp="$(mktemp -d)"
    echo "bootstrap: installing kubectl-view-secret v${_kvs_ver} (${_kvs_os}/${_kvs_arch})..."
    if curl -fsSL "$_kvs_url" | tar -xz -C "$_kvs_tmp"; then
      mkdir -p "$HOME/.local/bin"
      mv "$_kvs_tmp/kubectl-view-secret" "$_kvs_bin"
      chmod +x "$_kvs_bin"
      echo "bootstrap: kubectl-view_secret installed at $_kvs_bin"
    else
      echo "bootstrap: kubectl-view-secret download failed — install manually from https://github.com/elsesiy/kubectl-view-secret/releases"
    fi
    rm -rf "$_kvs_tmp"
  fi

  _proj_dir="${XDG_PROJECTS_DIR:-$HOME/projects}"
  _ws_live="$_proj_dir/laidback-system.code-workspace"
  _ws_starter="$_proj_dir/laidback-system.code-workspace.example"
  if [ -L "$_ws_live" ] && [ ! -e "$_ws_live" ]; then
    rm "$_ws_live"
  fi
  if [ ! -e "$_ws_live" ] && [ -e "$_ws_starter" ]; then
    cp "$_ws_starter" "$_ws_live"
    echo "bootstrap: copied workspace starter -> $_ws_live (edit freely; not tracked)"
  fi

  chmod +x "$HOME/.config/mise/tasks/dotfiles/"*.sh "$HOME/.config/mise/tasks/projects/"*.sh 2>/dev/null || true
  echo "bootstrap: global mise tasks ready at ~/.config/mise/tasks/{dotfiles,projects}/"
}

run_status() {
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
      printf "  %-22s symlink -> %s\n" "$label" "$(readlink "$path")"
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
  printf "  %-22s %s\n" "XDG_CONFIG_HOME" "$XDG_CONFIG_HOME"
  printf "  %-22s %s\n" "XDG_DATA_HOME" "$XDG_DATA_HOME"
  printf "  %-22s %s\n" "XDG_STATE_HOME" "$XDG_STATE_HOME"
  printf "  %-22s %s\n" "XDG_CACHE_HOME" "$XDG_CACHE_HOME"
  echo ""
  echo "  repository"
  _branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  _commit="$(git log -1 --format="%h %s" 2>/dev/null || echo unknown)"
  printf "  %-22s %s\n" "branch" "$_branch"
  printf "  %-22s %s\n" "commit" "$_commit"
  echo ""
  echo "  stow symlinks"
  _sym "env.sh" "$HOME/.config/shell/env.sh"
  _sym "mise config" "$HOME/.config/mise/config.toml"
  _sym ".zshrc" "$HOME/.zshrc"
  _sym ".zprofile" "$HOME/.zprofile"
  _sym ".profile" "$HOME/.profile"
  _sym ".vimrc" "$HOME/.vimrc"
  _sym "git/config" "$HOME/.config/git/config"
  _sym "git/ignore" "$HOME/.config/git/ignore"
  _sym "git/attributes" "$HOME/.config/git/attributes"
  echo ""
  echo "  git identity"
  _git_name="$(git config --global user.name 2>/dev/null || true)"
  _git_email="$(git config --global user.email 2>/dev/null || true)"
  printf "  %-22s %s\n" "user.name" "${_git_name:-(not set -- see CONFIGURATION.md)}"
  printf "  %-22s %s\n" "user.email" "${_git_email:-(not set -- see CONFIGURATION.md)}"
  _found_forge=0
  for _cfg in "$HOME/.config/git/"*.config; do
    [ -f "$_cfg" ] || continue
    [ "${_cfg##*/}" = "config" ] && continue
    printf "  %-22s %s\n" "forge config" "$(basename "$_cfg")"
    _found_forge=$((_found_forge + 1))
  done
  [ "$_found_forge" -eq 0 ] && printf "  %-22s %s\n" "forge configs" "(none -- see CONFIGURATION.md)"
  echo ""
  echo "  tools"
  for _tool in mise git stow vim delta kubectl gh jq sops age starship markdownlint; do
    if command -v "$_tool" >/dev/null 2>&1; then
      _ver_raw="$("$_tool" --version 2>/dev/null || true)"
      _ver="$(printf '%s' "$_ver_raw" | head -1)"
      [ -z "$_ver" ] && _ver="installed (version unavailable)"
      printf "  %-22s %s\n" "$_tool" "$_ver"
    else
      printf "  %-22s %s\n" "$_tool" "not found"
    fi
  done
  _bash_active="$(bash --version 2>/dev/null | head -1 || true)"
  [ -z "$_bash_active" ] && _bash_active="not found"
  printf "  %-22s %s\n" "bash (active)" "$_bash_active"

  _bash_brew=""
  if [ -x /opt/homebrew/bin/bash ]; then
    _bash_brew="/opt/homebrew/bin/bash"
  elif [ -x /usr/local/bin/bash ]; then
    _bash_brew="/usr/local/bin/bash"
  fi
  if [ -n "$_bash_brew" ]; then
    _bash_brew_ver="$("$_bash_brew" --version 2>/dev/null | head -1 || true)"
    printf "  %-22s %s (%s)\n" "bash (brew)" "${_bash_brew_ver:-installed}" "$_bash_brew"
  elif [ "$(uname -s)" = "Darwin" ]; then
    printf "  %-22s %s\n" "bash (brew)" "not found (install via brew install bash)"
  fi
  if command -v markdownlint >/dev/null 2>&1; then
    _md_path="$(command -v markdownlint)"
    if [ "$_md_path" = "$HOME/.local/share/mise/shims/markdownlint" ]; then
      printf "  %-22s %s\n" "markdownlint source" "mise shim (expected: Homebrew formula)"
    else
      printf "  %-22s %s\n" "markdownlint source" "$_md_path"
    fi
  fi
  echo "======================================================================"
}

run_doctor() {
  : "${LAIDBACK_DOTFILES_ROOT:=$(pwd)}"
  : "${XDG_CONFIG_HOME:=$HOME/.config}"

  _pass() { printf "  %-38s PASS\n" "$1"; }
  _fail() { printf "  %-38s FAIL  %s\n" "$1" "$2"; _errors=$((_errors + 1)); }
  _warn() { printf "  %-38s WARN  %s\n" "$1" "$2"; }
  _errors=0

  _check() {
    local label="$1" cond="$2" msg="${3:-}"
    if eval "$cond" >/dev/null 2>&1; then
      _pass "$label"
    elif [ -n "$msg" ]; then
      _warn "$label" "$msg"
    else
      _fail "$label" "(failed)"
    fi
  }

  _require() {
    local label="$1" cond="$2" msg="${3:-}"
    if eval "$cond" >/dev/null 2>&1; then
      _pass "$label"
    else
      _fail "$label" "$msg"
    fi
  }

  echo "======================================================================"
  echo "  laidback-dotfiles  doctor"
  echo "======================================================================"
  echo ""

  _require "repo: dotfiles present" "[ -d \"$LAIDBACK_DOTFILES_ROOT/.git\" ]" "not found at $LAIDBACK_DOTFILES_ROOT"
  _require "stow: env.sh symlinked" "[ -L \"$HOME/.config/shell/env.sh\" ]" "run: mise run bootstrap"
  _check "stow: mise/config.toml" "[ -L \"$HOME/.config/mise/config.toml\" ]" "not a symlink"
  _check "stow: .zshrc" "[ -L \"$HOME/.zshrc\" ]" "not a symlink"
  _check "stow: .zprofile" "[ -L \"$HOME/.zprofile\" ]" "not a symlink"
  _check "stow: .bashrc" "[ -L \"$HOME/.bashrc\" ]" "not a symlink"
  _check "stow: .bash_profile" "[ -L \"$HOME/.bash_profile\" ]" "not a symlink"
  _check "stow: starship.toml" "[ -L \"$HOME/.config/starship.toml\" ]" "not a symlink"
  _check "stow: motd.sh" "[ -L \"$HOME/.config/shell/motd.sh\" ]" "not a symlink"
  _check "stow: projects:clone" "[ -L \"$HOME/.config/mise/tasks/projects/clone.sh\" ] || [ -e \"$HOME/.config/mise/tasks/projects/clone.sh\" ]" "not present"
  _check "stow: projects:fingerprint" "[ -L \"$HOME/.config/mise/tasks/projects/fingerprint.sh\" ] || [ -e \"$HOME/.config/mise/tasks/projects/fingerprint.sh\" ]" "not present"
  _check "stow: .vimrc" "[ -L \"$HOME/.vimrc\" ]" "not a symlink"
  _check "stow: git/config" "[ -L \"$HOME/.config/git/config\" ]" "not a symlink"
  _check "stow: git/ignore" "[ -L \"$HOME/.config/git/ignore\" ]" "not a symlink"
  _check "stow: git/attributes" "[ -L \"$HOME/.config/git/attributes\" ]" "not a symlink"
  _check "stow: git/hooks dir" "[ -d \"$HOME/.config/git/hooks\" ]" "not a directory"
  _check "git: no plain ~/.gitconfig" "[ ! -f \"$HOME/.gitconfig\" ] || [ -L \"$HOME/.gitconfig\" ]" "plain file overrides XDG config; run: mise run bootstrap"
  _check "git: user.name configured" "git config --global user.name 2>/dev/null | grep -q ." "not set; see CONFIGURATION.md -> Git Identity"
  _check "git: user.email configured" "git config --global user.email 2>/dev/null | grep -q ." "not set; see CONFIGURATION.md -> Git Identity"
  _require "tool: mise" "command -v mise" "not in PATH"
  _require "tool: git" "command -v git" "not in PATH"
  _check "tool: stow" "command -v stow" "run bootstrap to auto-install"
  if [ "$(uname -s)" = "Darwin" ]; then
    _check "tool: brew" "command -v brew" "required on macOS; install Homebrew and re-run bootstrap"
    _require "tool: markdownlint (brew)" "command -v brew && brew list --formula markdownlint-cli >/dev/null 2>&1" "install via brew: brew install markdownlint-cli"
    _require "tool: starship" "command -v starship" "install via brew: brew install starship"
    _require "tool: bash (brew path)" "[ -x /opt/homebrew/bin/bash ] || [ -x /usr/local/bin/bash ]" "install via brew: brew install bash"
    _require "tool: bash >= 5" "( [ -x /opt/homebrew/bin/bash ] && /opt/homebrew/bin/bash -lc '((BASH_VERSINFO[0] >= 5))' ) || ( [ -x /usr/local/bin/bash ] && /usr/local/bin/bash -lc '((BASH_VERSINFO[0] >= 5))' )" "brew bash must be v5+ (macOS /bin/bash is 3.2)"
  fi
  _check "tool: vim" "command -v vim" "optional"
  _check "tool: delta" "command -v delta" "optional"
  _check "tool: sops" "command -v sops" "optional"
  _check "tool: age" "command -v age" "optional"
  _check "vim: vim-plug" "[ -f \"$HOME/.vim/autoload/plug.vim\" ]" "run: mise run bootstrap"
  _check "kubectl: view-secret plugin" "[ -x \"$HOME/.local/bin/kubectl-view_secret\" ]" "run: mise run bootstrap"
  _require "global task: dotfiles:status" "[ -x \"$HOME/.config/mise/tasks/dotfiles/status.sh\" ]" "run: mise run bootstrap"
  _require "global task: dotfiles:doctor" "[ -x \"$HOME/.config/mise/tasks/dotfiles/doctor.sh\" ]" "run: mise run bootstrap"

  echo ""
  if [ "$_errors" -eq 0 ]; then
    echo "  doctor: ok"
  else
    printf "  doctor: %d check(s) failed\n" "$_errors"
    exit 1
  fi
  echo "======================================================================"
}

run_json_lint() {
  files="$(find . -type f -name "*.json" | grep -v "^./.git/" || true)"
  if [ -n "$files" ]; then
    echo "$files" | while IFS= read -r file; do
      jq empty "$file" >/dev/null
    done
  fi
}

run_docker_lint() {
  if ! command -v hadolint >/dev/null 2>&1; then
    echo "docker:lint: hadolint not found — skipping"
    exit 0
  fi
  set +e
  hadolint --config .hadolint.yaml Dockerfile
  _exit=$?
  set -e
  if [ "$_exit" -eq 139 ] || [ "$_exit" -eq 134 ]; then
    echo "docker:lint: hadolint crashed (arm64 binary issue on macOS — skipping)"
    echo "docker:lint: lint will run in CI on ubuntu-24.04/amd64"
    exit 0
  fi
  exit "$_exit"
}

run_docker_build() {
  : "${IMAGE:=laidback-dotfiles:latest}"
  EXTRA_CA=""
  [ -f ZscalerRootCA.pem ] && EXTRA_CA="--secret id=extra_ca,src=ZscalerRootCA.pem"
  # shellcheck disable=SC2086
  docker build $EXTRA_CA --target runtime -t "$IMAGE" .
  echo "docker:build: $IMAGE"
}

run_docker_test() {
  : "${IMAGE:=laidback-dotfiles:test}"
  EXTRA_CA=""
  [ -f ZscalerRootCA.pem ] && EXTRA_CA="--secret id=extra_ca,src=ZscalerRootCA.pem"
  # shellcheck disable=SC2086
  docker build $EXTRA_CA --target test -t "$IMAGE" .
  docker run --rm "$IMAGE" bash -c "echo \"docker:test: ok - image=$IMAGE\""
  echo "docker:test: passed"
}

run_docker_run() {
  : "${IMAGE:=laidback-dotfiles:latest}"
  docker run --rm -it "$IMAGE"
}

run_docker_push() {
  : "${IMAGE:?set IMAGE=registry/repo:tag}"
  docker push "$IMAGE"
  echo "docker:push: $IMAGE"
}

run_sops_check() {
  command -v sops >/dev/null 2>&1 && command -v age >/dev/null 2>&1 && echo "security sops/age check: ok"
}

run_secrets_init() {
  : "${XDG_CONFIG_HOME:=$HOME/.config}"
  : "${LAIDBACK_CONFIG:=$XDG_CONFIG_HOME/laidback}"
  command -v sops >/dev/null 2>&1 || { echo "secrets:init: sops not installed (run: mise install sops)" >&2; exit 1; }
  command -v age >/dev/null 2>&1 || { echo "secrets:init: age not installed (run: mise install age)" >&2; exit 1; }
  command -v age-keygen >/dev/null 2>&1 || { echo "secrets:init: age-keygen not in PATH" >&2; exit 1; }

  _age_dir="$XDG_CONFIG_HOME/sops/age"
  _age_key="$_age_dir/keys.txt"
  mkdir -p "$_age_dir" "$LAIDBACK_CONFIG"
  chmod 700 "$_age_dir"

  if [ -s "$_age_key" ]; then
    echo "secrets:init: age key already present at $_age_key (skipping)"
  else
    age-keygen -o "$_age_key"
    chmod 600 "$_age_key"
    echo "secrets:init: generated age key at $_age_key"
  fi

  _pubkey="$(grep "^# public key:" "$_age_key" | awk "{print \$NF}")"
  [ -n "$_pubkey" ] || { echo "secrets:init: could not extract public key from $_age_key" >&2; exit 1; }

  _sops_cfg="$LAIDBACK_CONFIG/.sops.yaml"
  if [ -f "$_sops_cfg" ]; then
    echo "secrets:init: $_sops_cfg already present (leaving as-is)"
  else
    cat >"$_sops_cfg" <<EOF
creation_rules:
  - path_regex: secrets\\.env\\.sops$
    age: $_pubkey
EOF
    echo "secrets:init: wrote $_sops_cfg (recipient: $_pubkey)"
  fi

  if [ ! -s "$LAIDBACK_CONFIG/secrets.env.sops" ] && [ -r "$HOME/.config/laidback/secrets.env.example" ]; then
    _tmp_plain="$LAIDBACK_CONFIG/secrets.env.plain.tmp"
    cp "$HOME/.config/laidback/secrets.env.example" "$_tmp_plain"
    chmod 600 "$_tmp_plain"
    (cd "$LAIDBACK_CONFIG" && sops --encrypt --age "$_pubkey" \
      --input-type dotenv --output-type dotenv \
      --filename-override secrets.env.sops "$_tmp_plain") >"$LAIDBACK_CONFIG/secrets.env.sops"
    rm -f "$_tmp_plain"
    echo "secrets:init: seeded $LAIDBACK_CONFIG/secrets.env.sops from template"
  fi

  cat <<EOF

next steps:
  1) mise run secrets:edit       # fill in tokens (GITHUB_TOKEN, GLAB_TOKEN, ...)
  2) mise run secrets:decrypt    # writes plaintext to $LAIDBACK_CONFIG/secrets.env (0600)
  3) start a new shell           # env.sh auto-sources it
  4) mise run secrets:status     # verify presence (no values printed)

age public key (share / use as recipient on other machines):
  $_pubkey
EOF
}

run_secrets_edit() {
  : "${XDG_CONFIG_HOME:=$HOME/.config}"
  : "${LAIDBACK_CONFIG:=$XDG_CONFIG_HOME/laidback}"
  _file="$LAIDBACK_CONFIG/secrets.env.sops"
  command -v sops >/dev/null 2>&1 || { echo "secrets:edit: sops not installed" >&2; exit 1; }
  [ -s "$_file" ] || { echo "secrets:edit: $_file not found — run: mise run secrets:init" >&2; exit 1; }
  SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$XDG_CONFIG_HOME/sops/age/keys.txt}" \
    sops --input-type dotenv --output-type dotenv "$_file"
  echo "secrets:edit: $_file updated — run: mise run secrets:decrypt"
}

run_secrets_decrypt() {
  : "${XDG_CONFIG_HOME:=$HOME/.config}"
  : "${LAIDBACK_CONFIG:=$XDG_CONFIG_HOME/laidback}"
  _src="$LAIDBACK_CONFIG/secrets.env.sops"
  _dst="$LAIDBACK_CONFIG/secrets.env"
  command -v sops >/dev/null 2>&1 || { echo "secrets:decrypt: sops not installed" >&2; exit 1; }
  [ -s "$_src" ] || { echo "secrets:decrypt: $_src not found — run: mise run secrets:init" >&2; exit 1; }
  mkdir -p "$LAIDBACK_CONFIG"
  SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$XDG_CONFIG_HOME/sops/age/keys.txt}" \
    sops --decrypt --input-type dotenv --output-type dotenv "$_src" >"$_dst"
  chmod 600 "$_dst"
  echo "secrets:decrypt: wrote $_dst (mode 600)"
  echo "secrets:decrypt: re-source your shell (or open a new terminal) to load it"
}

run_secrets_encrypt() {
  : "${XDG_CONFIG_HOME:=$HOME/.config}"
  : "${LAIDBACK_CONFIG:=$XDG_CONFIG_HOME/laidback}"
  _src="$LAIDBACK_CONFIG/secrets.env"
  _dst="$LAIDBACK_CONFIG/secrets.env.sops"
  command -v sops >/dev/null 2>&1 || { echo "secrets:encrypt: sops not installed" >&2; exit 1; }
  [ -s "$_src" ] || { echo "secrets:encrypt: $_src not found" >&2; exit 1; }
  SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$XDG_CONFIG_HOME/sops/age/keys.txt}" \
    sops --encrypt --input-type dotenv --output-type dotenv "$_src" >"$_dst"
  echo "secrets:encrypt: wrote $_dst"
}

run_secrets_status() {
  : "${XDG_CONFIG_HOME:=$HOME/.config}"
  : "${LAIDBACK_CONFIG:=$XDG_CONFIG_HOME/laidback}"
  _template="$HOME/.config/laidback/secrets.env.example"
  _decrypted="$LAIDBACK_CONFIG/secrets.env"

  echo "secrets:status"
  printf "  %-30s %s\n" "template" "$_template"
  printf "  %-30s %s\n" "decrypted" "$_decrypted"
  if [ -e "$_decrypted" ]; then
    _mode="$(stat -f %A "$_decrypted" 2>/dev/null || stat -c %a "$_decrypted" 2>/dev/null || echo ?)"
    printf "  %-30s mode=%s\n" "  permissions" "$_mode"
    if [ "$_mode" != "600" ]; then
      printf "  %-30s WARN: should be 600 — run: chmod 600 %s\n" "  permissions" "$_decrypted"
    fi
  fi
  echo
  [ -r "$_template" ] || { echo "  no template found — run: mise run secrets:init" >&2; exit 0; }
  echo "  expected variables (from template):"
  while IFS= read -r _line; do
    case "$_line" in
      ""|"#"*) continue ;;
    esac
    _var="${_line%%=*}"
    [ -n "$_var" ] || continue
    if eval "[ -n \"\${$_var:-}\" ]"; then
      printf "    %-30s SET\n" "$_var"
    else
      printf "    %-30s missing\n" "$_var"
    fi
  done <"$_template"
}

run_build() {
  mkdir -p dist
  stamp="$(date +%Y%m%d-%H%M%S)"
  includes=""
  for f in README.md ARCHITECTURE.md Dockerfile Makefile install.sh mise home init .github; do
    [ -e "$f" ] && includes="$includes $f"
  done
  # shellcheck disable=SC2086
  tar -czf "dist/dotfiles-${stamp}.tar.gz" $includes
  echo "build artifact: dist/dotfiles-${stamp}.tar.gz"
}

run_release_check() {
  git diff --quiet || { echo "release-check: working tree has changes" >&2; exit 1; }
  echo "release-check: ok"
}

run_release_dry_run() {
  echo "release dry-run"
  echo "1) mise run release-check"
  echo "2) mise run release:tag TAG=vX.Y.Z"
  echo "3) mise run release:publish TAG=vX.Y.Z"
}

run_release_tag() {
  : "${TAG:?set TAG=vX.Y.Z}"
  git diff --quiet || { echo "release-tag: working tree has changes" >&2; exit 1; }
  git rev-parse --verify "$TAG" >/dev/null 2>&1 && { echo "release-tag: tag exists" >&2; exit 1; }
  git tag -a "$TAG" -m "release $TAG"
  echo "created tag: $TAG"
}

run_release_publish() {
  : "${TAG:?set TAG=vX.Y.Z}"
  git rev-parse --verify "$TAG" >/dev/null 2>&1
  git push origin "$TAG"
  echo "published tag: $TAG"
}

run_ci_act() {
  [ -f .secrets.act ] || { echo "missing .secrets.act (copy from .secrets.act.example)" >&2; exit 1; }
  act -W .github/workflows/ci.yml
}

run_vscode_tasks_check() {
  _vscode_file=".vscode/tasks.json"
  _mise_file="mise/config.toml"

  [ -f "$_vscode_file" ] || { echo "vscode:tasks-check: missing $_vscode_file" >&2; exit 1; }
  [ -f "$_mise_file" ] || { echo "vscode:tasks-check: missing $_mise_file" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "vscode:tasks-check: jq is required" >&2; exit 1; }

  _non_mise_labels="$(jq -r '.tasks[] | select((.command // "") | contains("mise run ") | not) | .label' "$_vscode_file")"
  if [ -n "$_non_mise_labels" ]; then
    echo "vscode:tasks-check: FAIL - non-canonical VS Code tasks found (must use 'mise run')" >&2
    while IFS= read -r _label; do
      [ -n "$_label" ] && echo "  - $_label" >&2
    done <<< "$_non_mise_labels"
    exit 1
  fi

  _vscode_tasks="$(jq -r '.tasks[].command // empty' "$_vscode_file" | grep -oE "mise run [^[:space:]\"']+" | awk '{print $3}' | sort -u || true)"
  _repo_tasks="$(grep -E '^\[tasks\."[^"]+"\]' "$_mise_file" | sed -E 's/^\[tasks\."([^"]+)"\].*/\1/' | sort -u)"

  _missing=0
  while IFS= read -r _task; do
    [ -n "$_task" ] || continue
    if ! printf '%s\n' "$_vscode_tasks" | grep -qx "$_task"; then
      if [ "$_missing" -eq 0 ]; then
        echo "vscode:tasks-check: FAIL - missing VS Code wrappers for repo mise tasks:" >&2
      fi
      echo "  - $_task" >&2
      _missing=1
    fi
  done <<< "$_repo_tasks"

  if [ "$_missing" -ne 0 ]; then
    exit 1
  fi

  echo "vscode:tasks-check: ok"
}

case "$_task" in
  bootstrap) run_bootstrap ;;
  status) run_status ;;
  doctor) run_doctor ;;
  json-lint) run_json_lint ;;
  docker-lint) run_docker_lint ;;
  docker-build) run_docker_build ;;
  docker-test) run_docker_test ;;
  docker-run) run_docker_run ;;
  docker-push) run_docker_push ;;
  security-sops-check) run_sops_check ;;
  secrets-init) run_secrets_init ;;
  secrets-edit) run_secrets_edit ;;
  secrets-decrypt) run_secrets_decrypt ;;
  secrets-encrypt) run_secrets_encrypt ;;
  secrets-status) run_secrets_status ;;
  build) run_build ;;
  release-check) run_release_check ;;
  release-dry-run) run_release_dry_run ;;
  release-tag) run_release_tag ;;
  release-publish) run_release_publish ;;
  ci-act) run_ci_act ;;
  vscode-tasks-check) run_vscode_tasks_check ;;
  *)
    echo "unknown task: $_task" >&2
    exit 1
    ;;
esac
