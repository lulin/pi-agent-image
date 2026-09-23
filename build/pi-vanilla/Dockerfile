# syntax=docker/dockerfile:1
#
# pi-vanilla image = Vanilla Pi layer, on top of deven.
#
#   docker build -f build/pi-vanilla/Dockerfile \
#     --build-arg BASE_IMAGE=deven:latest \
#     -t pi-vanilla:latest .
#
# Build args:
#   BASE_IMAGE   deven image to build on (default: deven:latest)
#   PI_VERSION   pi version to bake in; empty = latest

# NOTE: this ARG must stay before FROM to be usable there.
ARG BASE_IMAGE=deven:latest
FROM ${BASE_IMAGE}

# Pin the pi version for reproducible builds.
# Build with --build-arg PI_VERSION=x.y.z to override; empty = latest.
ARG PI_VERSION=

LABEL org.opencontainers.image.title="pi-vanilla" \
      org.opencontainers.image.description="Pi coding agent (terminal AI harness), unmodified, on the deven toolchain image" \
      org.opencontainers.image.source="https://github.com/earendil-works/pi-mono"

# Install pi globally. --ignore-scripts skips dependency lifecycle scripts,
# as recommended by the official install instructions.
RUN set -eux; \
    if [ -n "$PI_VERSION" ]; then \
      npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@${PI_VERSION}"; \
    else \
      npm install -g --ignore-scripts @earendil-works/pi-coding-agent; \
    fi; \
    pi --version

# Projects are mounted here at runtime:
#   docker run -v "$PWD:/workspace" ...
WORKDIR /workspace

# Provider API keys are passed at runtime, e.g.:
#   docker run -e ANTHROPIC_API_KEY ...
ENTRYPOINT ["pi"]
