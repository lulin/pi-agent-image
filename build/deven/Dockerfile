# syntax=docker/dockerfile:1
#
# deven image = Base layer (Ubuntu 24.04) + Toolchain layer (uv/Python, Node.js, Rust).
#
#   docker build -f build/deven/Dockerfile -t deven:latest .
#
# Build args:
#   NODE_VERSION   Node.js major version to bake in (default: 24)
#   RUST_VERSION   rustup default toolchain, e.g. "stable" or "1.90.0"
#
# NOTE: the base is glibc-based (not Alpine/musl) on purpose: official Node
# tarballs, rustup, and most prebuilt toolchains (Racket, etc.) are glibc
# binaries that do not run on musl.

########################################
# Base layer: Ubuntu 24.04 LTS (noble)
########################################
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps:
#   bash, ca-certificates, git  -> required by pi's bash tool and git workflows
#   ripgrep, fd-find            -> used by pi's grep/find tools
#   curl, jq                    -> handy for web fetch / scripting inside the container
#   openssh-client              -> git over SSH if you mount keys
#   vim, iputils-ping           -> convenience
# Build deps (needed to compile/link Rust and most C-dependent crates):
#   build-essential             -> cc linker, make, headers
#   pkg-config                  -> pkg-config for native crate builds
#   libssl-dev                  -> openssl-sys (very common crate dependency)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       bash \
       build-essential \
       ca-certificates \
       curl \
       fd-find \
       git \
       iputils-ping \
       jq \
       openssh-client \
       pkg-config \
       libssl-dev \
       ripgrep \
       tar \
       unzip \
       vim \
       which \
       xz-utils \
       zip \
  && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
  && rm -rf /var/lib/apt/lists/*

########################################
# Toolchain layer: node / uv+python / rust
########################################
FROM base AS toolchain

# ---- Node.js (official upstream binaries; Ubuntu's nodejs package lags majors) ----
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

# ---- uv (official installer) ----
#   UV_INSTALLER_GITHUB_BASE_URL is an official mirror hook; upstream GitHub
#   is the default here (build/ is built by GitHub Actions runners).
ARG UV_VERSION=0.12.18
ARG UV_INSTALLER_GITHUB_BASE_URL=https://github.com
RUN set -eux; \
    curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALLER_GITHUB_BASE_URL="$UV_INSTALLER_GITHUB_BASE_URL" \
            UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 \
            sh; \
    uv --version

# ---- uv + a system-managed CPython ----
# Installed under /opt so it works for any user. The managed interpreter has no
# pip; use `uv pip` / `uv add` / `uv run`.
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
      org.opencontainers.image.description="Development environment: Ubuntu 24.04 + uv/Python 3.14 + Node.js 24 + Rust"
