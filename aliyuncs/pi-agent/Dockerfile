# syntax=docker/dockerfile:1
#
# pi-agent image (ACR cloud-builder variant)
# = Pi extensions layer + Patch layer, on top of pi-vanilla.
#
# Functional mirror of build/pi-agent/Dockerfile. The npm registry is patched
# *before* the extensions layer (so any baked-in `pi install npm:...` uses the
# configured mirror), otherwise identical layer order.
#
# ACR builder settings:
#   Dockerfile path: aliyuncs/pi-agent/Dockerfile
#   Context directory: repo root (no context files are used)
#   Namespace/repo:  <ns>/pi-agent     Tag: latest (+ version rule)
#   Build AFTER the pi-vanilla builder has produced <ns>/pi-vanilla:latest.
# See aliyuncs/README.md for the full builder matrix.

# NOTE: this ARG must stay before FROM to be usable there.
# Same-region builders can use the VPC endpoint for a fast internal pull:
#   registry-vpc.cn-hangzhou.aliyuncs.com/lulinw/pi-vanilla:latest
ARG BASE_IMAGE=registry.cn-hangzhou.aliyuncs.com/lulinw/pi-vanilla:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="pi-agent" \
      org.opencontainers.image.description="Pi coding agent with baked-in extensions and regional mirror configuration" \
      org.opencontainers.image.source="https://github.com/earendil-works/pi-mono"

########################################
# Patch (build-time part): npm registry
########################################
# Applied first in this variant so the extensions layer below downloads from
# the mirror. This is also the *runtime* npm configuration, same as in
# build/pi-agent/Dockerfile — nothing extra is baked.
# Values: npmmirror (default) / none (upstream registry.npmjs.org)
ARG NPM_MIRROR=npmmirror
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

########################################
# Pi extensions layer
########################################
# Pi packages (extensions/skills/themes) installed with `pi install` land in
# the build user's ~/.pi/agent; the container HOME is not mounted at runtime,
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
# Per-run override without rebuilding, e.g.:
#   docker run -e UV_DEFAULT_INDEX=https://pypi.org/simple ...
ARG APT_MIRROR=ustc
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

# PyPI mirror used by uv. Written to /etc/uv/uv.toml, uv's system-wide config
# (applies to every user/project without a local uv.toml), marked
# `default = true` so it replaces pypi.org for all resolutions:
#   ustc  -> https://mirrors.ustc.edu.cn/pypi/simple
#   tuna  -> https://pypi.tuna.tsinghua.edu.cn/simple
#   none  -> keep upstream pypi.org
# Note: `uv python install` fetches CPython builds via UV_PYTHON_INSTALL_MIRROR
# (already set in the deven image), not PyPI, so it is unaffected here.
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
