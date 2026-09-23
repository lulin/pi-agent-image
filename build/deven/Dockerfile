# syntax=docker/dockerfile:1
#
# deven image = Base layer (Alpine Linux) + Toolchain layer (uv/Python, Node.js, Rust).
#
#   docker build -f build/deven/Dockerfile -t deven:latest .
#
# Build args:
#   NODE_VERSION   Node.js major version to bake in (default: 24)
#   RUST_VERSION   rustup default toolchain, e.g. "stable" or "1.90.0"

########################################
# Base layer: Alpine Linux
########################################
FROM alpine:3.22 AS base

# Runtime tools:
#   bash, ca-certificates, git  -> required by pi's bash tool and git workflows
#   ripgrep, fd, grep, findutils-> used by pi's grep/find tools
#   curl, jq                    -> handy for web fetch / scripting inside the container
#   openssh-client              -> git over SSH if you mount keys
#   vim, iputils                -> convenience
# Toolchain build deps (also kept for runtime `cargo install` / native builds):
#   build-base                  -> cc linker, make, headers
#   pkgconf                     -> pkg-config for native crate builds
#   openssl-dev                 -> openssl-sys (very common crate dependency)
RUN apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      curl \
      fd \
      findutils \
      git \
      grep \
      iputils \
      jq \
      openssh-client \
      ripgrep \
      tar \
      unzip \
      vim \
      which \
      xz \
      zip \
      build-base \
      pkgconf \
      openssl-dev

########################################
# Toolchain layer: node / uv+python / rust
########################################
FROM base AS toolchain

# ---- Node.js (official upstream binaries; Alpine's nodejs package lags majors) ----
ARG NODE_VERSION=24
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  NARCH=x64 ;; \
      aarch64) NARCH=arm64 ;; \
      *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    BASE_URL="https://nodejs.org/dist/latest-v${NODE_VERSION}.x"; \
    TARBALL="$(curl -fsSL "${BASE_URL}/" \
        | grep -oE "node-v${NODE_VERSION}\.[0-9]+\.[0-9]+-linux-${NARCH}\.tar\.xz" \
        | head -1)"; \
    test -n "$TARBALL"; \
    curl -fsSL "${BASE_URL}/${TARBALL}" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f /tmp/node.tar.xz; \
    node --version && npm --version && npx --version

# ---- uv + a system-managed CPython ----
# Installed under /opt so it works for any user. The managed interpreter has no
# pip; use `uv pip` / `uv add` / `uv run`.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
RUN set -eux; \
    mkdir -p "$UV_PYTHON_INSTALL_DIR"; \
    uv python install 3.14; \
    ln -sf "$(uv python find --no-project 3.14)" /usr/local/bin/python3.14; \
    ln -sf python3.14 /usr/local/bin/python; \
    ln -sf python3.14 /usr/local/bin/python3; \
    chmod -R a+rX /opt/uv; \
    uv --version && python --version

# ---- Rust toolchain via rustup (system-wide under /opt) ----
# `minimal` profile + clippy/rustfmt keeps the image lean but useful.
ARG RUST_VERSION=stable
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH \
    CARGO_NET_GIT_FETCH_WITH_CLI=true
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y \
          --profile minimal \
          --default-toolchain "$RUST_VERSION" \
          --component clippy,rustfmt \
          --no-modify-path; \
    chmod -R a+rX "$RUSTUP_HOME" "$CARGO_HOME"; \
    rustc --version && cargo --version && cargo clippy --version && cargo fmt --version

########################################
# Final: deven == base + toolchain
########################################
FROM toolchain AS deven

LABEL org.opencontainers.image.title="deven" \
      org.opencontainers.image.description="Development environment: Alpine + uv/Python 3.14 + Node.js 24 + Rust"
