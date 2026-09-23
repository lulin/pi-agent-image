# syntax=docker/dockerfile:1
#
# deven image (ACR cloud-builder variant)
# = Base layer (Ubuntu 24.04) + Toolchain layer (uv/Python, Node.js, Rust).
#
# Functional mirror of build/deven/Dockerfile, but every overseas build-time
# source is parameterized and defaults to a mainland-friendly mirror, so an
# ACR builder service in a China-mainland region can fetch everything locally.
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

# Build-time apt mirror: ustc (default) / tuna / none.
# NOTE: only affects *this image build*; the runtime mirror configuration is
# written by the patch layer in aliyuncs/pi-agent/Dockerfile.
ARG APT_MIRROR=ustc
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

# ---- uv (official installer; supports a GitHub-releases mirror) ----
#   UV_INSTALLER_GITHUB_BASE_URL:  https://gh-proxy.com/https://github.com (default,
#     mainland-friendly) or https://github.com for upstream; the installer also
#     falls back to releases.astral.sh automatically.
ARG UV_VERSION=0.12.18
ARG UV_INSTALLER_GITHUB_BASE_URL=https://gh-proxy.com/https://github.com
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
# uv python builds come from GitHub releases by default; npmmirror mirrors
# python-build-standalone with the same <tag>/<file> layout. Set
# UV_PYTHON_INSTALL_MIRROR="" to go back upstream.
ARG PYTHON_VERSION=3.14
ARG UV_PYTHON_INSTALL_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_PYTHON_INSTALL_MIRROR=${UV_PYTHON_INSTALL_MIRROR}
RUN set -eux; \
    mkdir -p "$UV_PYTHON_INSTALL_DIR"; \
    uv python install "$PYTHON_VERSION"; \
    ln -sf "$(uv python find --no-project "$PYTHON_VERSION")" "/usr/local/bin/python${PYTHON_VERSION}"; \
    ln -sf "python${PYTHON_VERSION}" /usr/local/bin/python; \
    ln -sf "python${PYTHON_VERSION}" /usr/local/bin/python3; \
    chmod -R a+rX /opt/uv; \
    uv --version && python --version

# ---- Rust toolchain via rustup (system-wide under /opt) ----
# `minimal` profile + clippy/rustfmt keeps the image lean but useful.
# rsproxy.cn (ByteDance) mirrors both the dist and the rustup update tree;
# upstream equivalents: https://static.rust-lang.org and
# https://static.rust-lang.org/rustup. ENV (not just build scope) so runtime
# `rustup toolchain install` is also accelerated.
ARG RUST_VERSION=stable
ARG RUSTUP_DIST_SERVER=https://rsproxy.cn
ARG RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
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
