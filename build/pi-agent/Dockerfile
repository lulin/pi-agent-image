# syntax=docker/dockerfile:1
#
# pi-agent image = Pi extensions layer + Patch layer, on top of pi-vanilla.
#
#   docker build -f build/pi-agent/Dockerfile \
#     --build-arg BASE_IMAGE=pi-vanilla:latest \
#     -t pi-agent:latest .
#
# Build args:
#   BASE_IMAGE   pi-vanilla image to build on (default: pi-vanilla:latest)
#   PI_PACKAGES  space-separated pi package specs to bake in, e.g.
#                "npm:@foo/bar@1.0.0 git:github.com/user/repo@v1"
#   *_MIRROR     regional package-manager mirrors for the patch layer, see below

# NOTE: this ARG must stay before FROM to be usable there.
ARG BASE_IMAGE=pi-vanilla:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="pi-agent" \
      org.opencontainers.image.description="Pi coding agent with baked-in extensions and regional mirror configuration" \
      org.opencontainers.image.source="https://github.com/earendil-works/pi-mono"

########################################
# Pi extensions layer
########################################
# Pi packages (extensions/skills/themes) are installed with `pi install` into
# the build user's ~/.pi/agent. The container's HOME is not mounted at runtime,
# so the baked-in packages travel with the image.
ARG PI_PACKAGES=
RUN set -eux; \
    for pkg in $PI_PACKAGES; do \
      pi install "$pkg"; \
    done; \
    if [ -n "$PI_PACKAGES" ]; then pi list; fi

########################################
# Patch layer: mirrors & configuration files
########################################
# China-mainland mirrors used at *runtime* by the package managers in this
# image. Values: "ustc" (default) / "tuna" / "none" (upstream).
# npm is handled separately: only npmmirror.com exists in practice.
# Per-run override without rebuilding, e.g.:
#   docker run -e UV_DEFAULT_INDEX=https://pypi.org/simple ...
ARG APT_MIRROR=ustc
ARG NPM_MIRROR=npmmirror
ARG PIP_MIRROR=ustc
ARG CARGO_MIRROR=ustc

# apt mirror -> rewrite URIs in /etc/apt/sources.list(.d/*), covering the
# deb822 ubuntu.sources shipped by Ubuntu 24.04 (archive/security/ports).
RUN set -eux; \
    case "$APT_MIRROR" in \
      ustc) MIRROR="https://mirrors.ustc.edu.cn/ubuntu" ;; \
      tuna) MIRROR="https://mirrors.tuna.tsinghua.edu.cn/ubuntu" ;; \
      none|"") MIRROR="" ;; \
      *) echo "unknown APT_MIRROR: $APT_MIRROR (expected: ustc, tuna or none)" >&2; exit 1 ;; \
    esac; \
    if [ -n "$MIRROR" ]; then \
      for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources; do \
        [ -f "$f" ] || continue; \
        sed -i -E "s#https?://(archive|security)\.ubuntu\.com/ubuntu#${MIRROR}#g; s#https?://ports\.ubuntu\.com/ubuntu-ports#${MIRROR}-ports#g" "$f"; \
      done; \
      echo "apt mirror: $MIRROR"; \
    else \
      echo "apt mirror: disabled (using archive.ubuntu.com)"; \
    fi; \
    apt-get update && rm -rf /var/lib/apt/lists/*

# npm registry mirror -> /usr/local/etc/npmrc (global npmrc, all users).
#   npmmirror -> https://registry.npmmirror.com (Alibaba mirror; USTC/TUNA do
#               not mirror the full npm registry, only nodejs binaries)
RUN set -eux; \
    case "$NPM_MIRROR" in \
      npmmirror|taobao) REGISTRY="https://registry.npmmirror.com" ;; \
      none|"") REGISTRY="" ;; \
      *) echo "unknown NPM_MIRROR: $NPM_MIRROR (expected: npmmirror or none)" >&2; exit 1 ;; \
    esac; \
    if [ -n "$REGISTRY" ]; then \
      npm config set --location=global registry "$REGISTRY"; \
      echo "npm mirror: $REGISTRY"; \
    else \
      echo "npm mirror: disabled (using registry.npmjs.org)"; \
    fi; \
    npm config get registry

# PyPI mirror used by uv. Written to /etc/uv/uv.toml, uv's system-wide config
# (applies to every user/project without a local uv.toml), marked
# `default = true` so it replaces pypi.org for all resolutions:
#   ustc  -> https://mirrors.ustc.edu.cn/pypi/simple
#   tuna  -> https://pypi.tuna.tsinghua.edu.cn/simple
#   none  -> keep upstream pypi.org
# Covers `uv pip install/compile`, `uv add`, `uv sync`, `uv tool install`, ...
# Note: `uv python install` fetches CPython builds from GitHub, not PyPI, so
# it is unaffected by this setting.
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

# Cargo mirror -> $CARGO_HOME/config.toml (system-wide, applies to every user):
#   ustc  -> sparse index *and* .crate files from mirrors.ustc.edu.cn
#   tuna  -> sparse index from mirrors.tuna.tsinghua.edu.cn (.crate files still
#            come from static.crates.io, per TUNA's index config.json)
#   none  -> keep upstream crates.io
# Note this only mirrors Cargo; rustup's own downloads can be mirrored
# separately via RUSTUP_DIST_SERVER / RUSTUP_UPDATE_ROOT if needed.
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
      rm -f "$CARGO_HOME/config.toml"; \
      echo "cargo mirror: disabled (using crates.io)"; \
    fi; \
    chmod -R a+rX "$CARGO_HOME"; \
    cargo --version
