# syntax=docker/dockerfile:1
# =============================================================================
# Dockerfile — laidback-dotfiles  (multi-stage)
#
# Stages:
#   base      — Debian slim + mise + stow; shared toolchain cache layer
#   test      — runs the full install + shell validation (CI target)
#   runtime   — minimal interactive shell image for manual use
#
# Build (default = runtime image):
#   docker build -t laidback-dotfiles:latest .
#
# Run only tests (CI):
#   docker build --target test -t laidback-dotfiles:test .
#   docker run --rm laidback-dotfiles:test
#
# Launch an interactive shell:
#   docker run --rm -it laidback-dotfiles:latest
#
# Add an enterprise root CA when the build host sits behind TLS interception:
#   docker build --secret id=extra_ca,src=ZscalerRootCA.pem --target test .
# =============================================================================

ARG DEBIAN_VERSION=bookworm-slim

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: base — shared OS layer with mise and stow
# ─────────────────────────────────────────────────────────────────────────────
FROM debian:${DEBIAN_VERSION} AS base

ARG USERNAME=laidback
ARG USER_UID=1000
ARG USER_GID=1000

# System packages: bash, zsh, stow (Perl-based, no binary release), git, curl, jq, ca-certs
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash zsh stow git curl ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

# Optionally install an extra root CA for corporate proxies such as Zscaler.
RUN --mount=type=secret,id=extra_ca,target=/run/secrets/extra_ca,required=false \
    if [ -s /run/secrets/extra_ca ]; then \
        cp /run/secrets/extra_ca /usr/local/share/ca-certificates/extra-ca.crt; \
        update-ca-certificates; \
    fi

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} \
               --create-home --shell /bin/bash ${USERNAME}

# Install mise to a system-wide path so all users can use it.
ENV MISE_INSTALL_PATH=/usr/local/bin/mise \
    MISE_DATA_DIR=/usr/local/share/mise \
    MISE_CACHE_DIR=/var/cache/mise \
    PATH=/usr/local/share/mise/shims:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://mise.run | sh \
    && chmod 0755 /usr/local/bin/mise

WORKDIR /workspace/dotfiles
# Copy in two layers so module cache is invalidated only when source changes.
COPY mise/config.toml ./mise/config.toml
COPY mise.lock        ./mise.lock

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: test — install all tools, run bootstrap, validate shells
# ─────────────────────────────────────────────────────────────────────────────
FROM base AS test

ENV HOME=/home/${USERNAME:-laidback} \
    XDG_CONFIG_HOME=/home/${USERNAME:-laidback}/.config \
    XDG_DATA_HOME=/home/${USERNAME:-laidback}/.local/share \
    XDG_STATE_HOME=/home/${USERNAME:-laidback}/.local/state \
    XDG_CACHE_HOME=/home/${USERNAME:-laidback}/.cache \
    XDG_PROJECTS_DIR=/home/${USERNAME:-laidback}/projects \
    LAIDBACK_FORGE=github.com/laidback \
    LAIDBACK_DOTFILES_ROOT=/workspace/dotfiles \
    MISE_CONFIG_DIR=/workspace/dotfiles/mise

# Copy the full source now that the mise layer is warm.
COPY . .

# Pre-create XDG dirs so stow has a valid target tree.
RUN mkdir -p \
      "$HOME/.config/shell" \
      "$HOME/.config/mise/tasks/dotfiles" \
      "$HOME/.local/share" \
      "$HOME/.local/state" \
      "$HOME/.cache" \
      "$HOME/projects" \
    && chown -R ${USERNAME}:${USERNAME} "$HOME" /workspace/dotfiles

USER ${USERNAME}

# Install toolchain, run bootstrap, then validate.
RUN mise install --yes \
    && chmod +x install.sh home/.config/mise/tasks/clone.sh home/.config/mise/tasks/dotfiles/*.sh \
    # syntax-check all shell scripts
    && bash -n install.sh \
    && find home/.config/mise/tasks -name '*.sh' -exec bash -n {} \; \
    # bootstrap: stows home/ into $HOME (global mise tasks come along for free)
    && stow --dir=/workspace/dotfiles --target="$HOME" --adopt --restow home \
    # validate the repo (lint + doctor)
    && mise trust --yes \
    && mise run validate \
    # verify env.sh is now a symlink (stow worked)
    && test -L "$HOME/.config/shell/env.sh" \
    # verify global tasks are reachable as symlinks
    && test -x "$HOME/.config/mise/tasks/clone.sh" \
    && test -x "$HOME/.config/mise/tasks/dotfiles/status.sh" \
    && test -x "$HOME/.config/mise/tasks/dotfiles/doctor.sh" \
    # run status and doctor as final smoke tests
    && bash "$HOME/.config/mise/tasks/dotfiles/status.sh" \
    && bash "$HOME/.config/mise/tasks/dotfiles/doctor.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: runtime — minimal interactive image (no build toolchain)
# ─────────────────────────────────────────────────────────────────────────────
FROM debian:${DEBIAN_VERSION} AS runtime

ARG VERSION=dev
ARG USERNAME=laidback
ARG USER_UID=1000
ARG USER_GID=1000

LABEL org.opencontainers.image.title="laidback-dotfiles" \
      org.opencontainers.image.description="Laidback home environment bootstrap" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/laidback/laidback-dotfiles"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash zsh stow git curl ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=secret,id=extra_ca,target=/run/secrets/extra_ca,required=false \
    if [ -s /run/secrets/extra_ca ]; then \
        cp /run/secrets/extra_ca /usr/local/share/ca-certificates/extra-ca.crt; \
        update-ca-certificates; \
    fi

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} \
               --create-home --shell /bin/bash ${USERNAME}

ENV MISE_INSTALL_PATH=/usr/local/bin/mise \
    MISE_DATA_DIR=/usr/local/share/mise \
    MISE_CACHE_DIR=/var/cache/mise \
    PATH=/usr/local/share/mise/shims:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://mise.run | sh \
    && chmod 0755 /usr/local/bin/mise

# Copy validated dotfiles from the test stage (not re-running bootstrap).
COPY --from=test --chown=${USERNAME}:${USERNAME} \
    /home/${USERNAME} /home/${USERNAME}

ENV HOME=/home/${USERNAME} \
    XDG_CONFIG_HOME=/home/${USERNAME}/.config \
    XDG_DATA_HOME=/home/${USERNAME}/.local/share \
    XDG_STATE_HOME=/home/${USERNAME}/.local/state \
    XDG_CACHE_HOME=/home/${USERNAME}/.cache \
    XDG_PROJECTS_DIR=/home/${USERNAME}/projects \
    LAIDBACK_FORGE=github.com/laidback

USER ${USERNAME}
WORKDIR /home/${USERNAME}

ENTRYPOINT ["/bin/bash", "--login"]
