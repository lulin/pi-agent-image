# Pi Agent container image
# Based on the official containerization guide:
# docs/containerization.md ("Plain Docker" pattern)

FROM docker.io/library/node:24-bookworm-slim

# Pin the pi version for reproducible builds.
# Build with --build-arg PI_VERSION=x.y.z to override; empty = latest.
ARG PI_VERSION=

LABEL org.opencontainers.image.title="pi-agent" \
      org.opencontainers.image.description="Pi coding agent (terminal AI harness) in a container" \
      org.opencontainers.image.source="https://github.com/earendil-works/pi-mono"

# Runtime deps:
#   bash, ca-certificates, git  -> required by pi's bash tool and git workflows
#   ripgrep                     -> used by pi's grep tool
#   curl, jq                    -> handy for web fetch / scripting inside the container
#   openssh-client              -> git over SSH if you mount keys
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
  && rm -rf /var/lib/apt/lists/*

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
