# syntax=docker/dockerfile:1
#
# pi-vanilla image (ACR cloud-builder variant)
# = Vanilla Pi layer, on top of deven.
#
# Functional mirror of build/pi-vanilla/Dockerfile; defaults are set so an
# ACR builder in a China-mainland region can pull the parent image and the pi
# npm package without cross-border traffic.
#
# ACR builder settings:
#   Dockerfile path: aliyuncs/pi-vanilla/Dockerfile
#   Context directory: repo root (no context files are used)
#   Namespace/repo:  <ns>/pi-vanilla   Tag: latest (+ version rule)
#   Build AFTER the deven builder has produced <ns>/deven:latest.
# See aliyuncs/README.md for the full builder matrix.

# NOTE: this ARG must stay before FROM to be usable there.
# Same-region builders can use the VPC endpoint for a fast internal pull:
#   registry-vpc.cn-hangzhou.aliyuncs.com/lulinw/deven:latest
ARG BASE_IMAGE=registry.cn-hangzhou.aliyuncs.com/lulinw/deven:latest
FROM ${BASE_IMAGE}

# Pi version to bake in; empty = latest.
ARG PI_VERSION=0.87.1
#   upstream:    https://registry.npmjs.org
#   npmmirror:   https://registry.npmmirror.com  (default; "none" = upstream)
ARG NPM_REGISTRY=https://registry.npmmirror.com

LABEL org.opencontainers.image.title="pi-vanilla" \
      org.opencontainers.image.description="Pi coding agent (terminal AI harness), unmodified, on the deven toolchain image" \
      org.opencontainers.image.source="https://github.com/earendil-works/pi-mono"

# Install pi globally. --ignore-scripts skips dependency lifecycle scripts,
# as recommended by the official install instructions.
RUN set -eux; \
    case "$NPM_REGISTRY" in none) NPM_REGISTRY="" ;; esac; \
    if [ -n "$PI_VERSION" ]; then \
      PKG="@earendil-works/pi-coding-agent@${PI_VERSION}"; \
    else \
      PKG="@earendil-works/pi-coding-agent"; \
    fi; \
    if [ -n "$NPM_REGISTRY" ]; then \
      npm install -g --ignore-scripts --registry "$NPM_REGISTRY" "$PKG"; \
    else \
      npm install -g --ignore-scripts "$PKG"; \
    fi; \
    pi --version

# Projects are mounted here at runtime:
#   docker run -v "$PWD:/workspace" ...
WORKDIR /workspace

# Provider API keys are passed at runtime, e.g.:
#   docker run -e ANTHROPIC_API_KEY ...
ENTRYPOINT ["pi"]
