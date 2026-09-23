# Pi Agent container image
# Based on the official containerization guide:
# docs/containerization.md ("Plain Docker" pattern)

FROM node:24-bookworm-slim

# Pin the pi version for reproducible builds.
# Build with --build-arg PI_VERSION=x.y.z to override; empty = latest.
ARG PI_VERSION=

# Rust toolchain version for rustup. "stable" by default;
# build with --build-arg RUST_VERSION=1.90.0 to pin.
ARG RUST_VERSION=stable

# crates.io mirror used for dependency downloads: "ustc" (default), "tuna" or "none".
# Build with --build-arg CARGO_MIRROR=none to use the upstream registry.
ARG CARGO_MIRROR=ustc

# PyPI mirror used by uv for dependency downloads: "ustc" (default), "tuna" or "none".
# Build with --build-arg PIP_MIRROR=none to use the upstream index.
ARG PIP_MIRROR=ustc

LABEL org.opencontainers.image.title="pi-agent" \
      org.opencontainers.image.description="Pi coding agent (terminal AI harness) in a container" \
      org.opencontainers.image.source="https://github.com/earendil-works/pi-mono"

# Runtime deps:
#   bash, ca-certificates, git  -> required by pi's bash tool and git workflows
#   ripgrep, fd-find            -> used by pi's grep/find tools
#   curl, jq                    -> handy for web fetch / scripting inside the container
#   openssh-client              -> git over SSH if you mount keys
#   vim, iputils-ping           -> convenience
# Build deps (needed to compile/link Rust and most C-dependent crates):
#   build-essential, pkg-config -> cc linker, make, headers
#   libssl-dev                  -> openssl-sys (very common crate dependency)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       bash \
       ca-certificates \
       curl \
       git \
       jq \
       openssh-client \
       ripgrep \
       fd-find \
       vim \
       iputils-ping \
       build-essential \
       pkg-config \
       libssl-dev \
  && rm -rf /var/lib/apt/lists/*

# Rust toolchain via rustup (Debian's rustc is far too old).
# Installed system-wide under /opt so it works for any user.
# `minimal` profile + clippy/rustfmt keeps the image lean but useful.
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH \
    CARGO_NET_GIT_FETCH_WITH_CLI=true

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y \
          --profile minimal \
          --default-toolchain "$RUST_VERSION" \
          --component clippy,rustfmt \
          --no-modify-path \
  && chmod -R a+rX "$RUSTUP_HOME" "$CARGO_HOME" \
  && rustc --version && cargo --version && cargo clippy --version && cargo fmt --version

# Point Cargo at a China-mainland crates.io mirror (written to $CARGO_HOME/config.toml,
# which is system-wide and therefore applies to every user of the image).
#   ustc  -> sparse index *and* .crate files served from mirrors.ustc.edu.cn
#   tuna  -> sparse index from mirrors.tuna.tsinghua.edu.cn (.crate files still
#            come from static.crates.io, per TUNA's index config.json)
#   none  -> keep upstream crates.io
# Note this only mirrors Cargo; rustup's own downloads can be mirrored separately
# via RUSTUP_DIST_SERVER / RUSTUP_UPDATE_ROOT if needed.
RUN set -eux; \
    case "$CARGO_MIRROR" in \
      ustc) MIRROR_URL="sparse+https://mirrors.ustc.edu.cn/crates.io-index/" ;; \
      tuna) MIRROR_URL="sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/" ;; \
      none|"") MIRROR_URL="" ;; \
      *) echo "unknown CARGO_MIRROR: $CARGO_MIRROR (expected: ustc, tuna or none)" >&2; exit 1 ;; \
    esac; \
    mkdir -p "$CARGO_HOME"; \
    if [ -n "$MIRROR_URL" ]; then \
      printf '[source.crates-io]\nreplace-with = "mirror"\n\n[source.mirror]\nregistry = "%s"\n' \
             "$MIRROR_URL" > "$CARGO_HOME/config.toml"; \
      echo "cargo mirror: $MIRROR_URL"; \
    else \
      echo "cargo mirror: disabled (using crates.io)"; \
    fi; \
    chmod -R a+rX "$CARGO_HOME"; \
    cargo --version

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Point uv at a China-mainland PyPI mirror. Written to /etc/uv/uv.toml, which is uv's
# system-wide config file (read for every user and every project without a local uv.toml),
# and marked `default = true` so it replaces pypi.org for all resolutions.
#   ustc  -> index *and* package files served from mirrors.ustc.edu.cn/pypi
#            (https://mirrors.ustc.edu.cn/pypi/web/simple redirects here)
#   tuna  -> index and files from pypi.tuna.tsinghua.edu.cn
#   none  -> keep upstream pypi.org
# This covers `uv pip install/compile`, `uv add`, `uv sync`, `uv tool install`, `uvx`, ...
# Per-run override without rebuilding: -e UV_DEFAULT_INDEX=https://pypi.org/simple
# Note: `uv python install` fetches CPython builds from GitHub, not PyPI, so it is
# unaffected by this setting.
RUN set -eux; \
    case "$PIP_MIRROR" in \
      ustc) INDEX_URL="https://mirrors.ustc.edu.cn/pypi/simple" ;; \
      tuna) INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple" ;; \
      none|"") INDEX_URL="" ;; \
      *) echo "unknown PIP_MIRROR: $PIP_MIRROR (expected: ustc, tuna or none)" >&2; exit 1 ;; \
    esac; \
    mkdir -p /etc/uv; \
    if [ -n "$INDEX_URL" ]; then \
      printf '[[index]]\nurl = "%s"\ndefault = true\n' "$INDEX_URL" > /etc/uv/uv.toml; \
      chmod 0644 /etc/uv/uv.toml; \
      echo "uv/pypi mirror: $INDEX_URL"; \
    else \
      rm -f /etc/uv/uv.toml; \
      echo "uv/pypi mirror: disabled (using pypi.org)"; \
    fi; \
    uv --version

RUN uv python install 3.14

# Install pi globally. --ignore-scripts skips dependency lifecycle scripts,
# as recommended by the official install instructions.
RUN if [ -n "$PI_VERSION" ]; then \
      npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"; \
    else \
      npm install -g --ignore-scripts @earendil-works/pi-coding-agent; \
    fi \
  && pi --version

# Projects are mounted here at runtime:
#   docker run -v "$PWD:/workspace" ...
WORKDIR /workspace

# Provider API keys are passed at runtime, e.g.:
#   docker run -e ANTHROPIC_API_KEY ...
ENTRYPOINT ["pi"]
