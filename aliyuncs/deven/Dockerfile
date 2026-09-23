# syntax=docker/dockerfile:1
#
# deven image (ACR cloud-builder variant)
# = Base layer (Ubuntu 24.04) + Toolchain layer (uv/Python, Node.js, Rust).
#
# ACR cloud builders can reach overseas sources fine, so the defaults here
# match build/deven/Dockerfile (upstream everywhere). The download sources
# are still parameterized (APT_MIRROR, NODE_DIST_URL, UV_..., RUSTUP_...)
# as overrides for restricted networks; *runtime* mirrors are configured by
# the patch layer in aliyuncs/pi-agent/Dockerfile.
#
# ACR builder settings:
#   Dockerfile path: aliyuncs/deven/Dockerfile
#   Context directory: repo root (no context files are used)
#   Namespace/repo:  <ns>/deven        Tag: latest (+ version rule)
# See aliyuncs/README.md for the full builder matrix.

# ---- external base image (overridable with a mirrored copy) ----
ARG BASE_IMAGE=ubuntu:24.04

########################################
# Base layer: Ubuntu 24.04 LTS (noble)
########################################
FROM ${BASE_IMAGE} AS base

ENV DEBIAN_FRONTEND=noninteractive

# Optional build-time apt mirror: ustc / tuna / none (default; upstream
# archive.ubuntu.com). NOTE: only affects *this image build*; the runtime
# mirror configuration is written by the patch layer in
# aliyuncs/pi-agent/Dockerfile.
ARG APT_MIRROR=none
RUN set -eux; \
    case "$APT_MIRROR" in \
      ustc) M="https://mirrors.ustc.edu.cn/ubuntu" ;; \
      tuna) M="https://mirrors.tuna.tsinghua.edu.cn/ubuntu" ;; \
      none|"") M="" ;; \
      *) echo "unknown APT_MIRROR: $APT_MIRROR (expected: ustc, tuna or none)" >&2; exit 1 ;; \
    esac; \
    if [ -n "$M" ]; then \
      for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do \
        [ -f "$f" ] || continue; \
        sed -i -E "s#https?://(archive|security)\.ubuntu\.com/ubuntu#${M}#g; s#https?://ports\.ubuntu\.com/ubuntu-ports#${M}-ports#g" "$f"; \
      done; \
      echo "build-time apt mirror: $M"; \
    else \
      echo "build-time apt mirror: disabled (using archive.ubuntu.com)"; \
    fi

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
       libssl-dev \
       openssh-client \
       pkg-config \
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
# Toolchain layer: uv+python / node / rust
########################################
FROM base AS toolchain

# ---- uv (official installer) ----
#   UV_INSTALLER_GITHUB_BASE_URL is an official mirror hook; upstream GitHub
#   is the default (ACR builders have overseas access). Mainland override for
#   restricted networks: https://gh-proxy.com/https://github.com
#   (the installer also falls back to releases.astral.sh automatically).
ARG UV_VERSION=0.12.18
ARG UV_INSTALLER_GITHUB_BASE_URL=https://github.com
RUN set -eux; \
    curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALLER_GITHUB_BASE_URL="$UV_INSTALLER_GITHUB_BASE_URL" \
            UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 \
            sh; \
    uv --version

# ---- Node.js (official tarball layout; npmmirror serves the same layout) ----
ARG NODE_VERSION=24
#   upstream:  https://nodejs.org/dist            (default)
#   npmmirror: https://registry.npmmirror.com/-/binary/node
#     CAVEAT: npmmirror's merged `latest-vX.x` listing is stale (e.g. it only
#     lists up to v24.1.0), so only select this mirror together with a pinned
#     full version, e.g. by editing the download to .../node/v24.21.0/<file>.
ARG NODE_DIST_URL=https://nodejs.org/dist
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  NARCH=x64 ;; \
      aarch64) NARCH=arm64 ;; \
      *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    LIST_URL="${NODE_DIST_URL}/latest-v${NODE_VERSION}.x"; \
    TARBALL="$(curl -fsSL "${LIST_URL}/" \
        | grep -oE "node-v${NODE_VERSION}\.[0-9]+\.[0-9]+-linux-${NARCH}\.tar\.xz" \
        | head -1)"; \
    test -n "$TARBALL"; \
    curl -fsSL "${LIST_URL}/${TARBALL}" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f /tmp/node.tar.xz; \
    node --version && npm --version && npx --version

# ---- uv + a system-managed CPython ----
# Installed under /opt so it works for any user. The managed interpreter has no
# pip; use `uv pip` / `uv add` / `uv run`.
# uv python builds come from GitHub releases by default (upstream). Optional
# build-time override for restricted networks (same <tag>/<file> layout):
#   UV_PYTHON_INSTALL_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone
ARG PYTHON_VERSION=3.14
ARG UV_PYTHON_INSTALL_MIRROR=
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
RUN set -eux; \
    mkdir -p "$UV_PYTHON_INSTALL_DIR"; \
    test -z "$UV_PYTHON_INSTALL_MIRROR" || export UV_PYTHON_INSTALL_MIRROR; \
    uv python install "$PYTHON_VERSION"; \
    ln -sf "$(uv python find --no-project "$PYTHON_VERSION")" "/usr/local/bin/python${PYTHON_VERSION}"; \
    ln -sf "python${PYTHON_VERSION}" /usr/local/bin/python; \
    ln -sf "python${PYTHON_VERSION}" /usr/local/bin/python3; \
    chmod -R a+rX /opt/uv; \
    uv --version && python --version

# ---- Rust toolchain via rustup (system-wide under /opt) ----
# `minimal` profile + clippy/rustfmt keeps the image lean but useful.
# Upstream static.rust-lang.org by default; mainland override for restricted
# networks: https://rsproxy.cn and https://rsproxy.cn/rustup.
# ENV (not just build scope) so runtime `rustup toolchain install` follows
# the same setting.
ARG RUST_VERSION=stable
ARG RUSTUP_DIST_SERVER=https://static.rust-lang.org
ARG RUSTUP_UPDATE_ROOT=https://static.rust-lang.org/rustup
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH \
    CARGO_NET_GIT_FETCH_WITH_CLI=true \
    RUSTUP_DIST_SERVER=${RUSTUP_DIST_SERVER} \
    RUSTUP_UPDATE_ROOT=${RUSTUP_UPDATE_ROOT}
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
      org.opencontainers.image.description="Development environment: Ubuntu 24.04 + uv/Python 3.14 + Node.js 24 + Rust (ACR-builder variant)"
