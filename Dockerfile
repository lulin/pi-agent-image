# Pi Agent container image
# Based on the official containerization guide:
# docs/containerization.md ("Plain Docker" pattern)

FROM docker.io/library/node:24-bookworm-slim

# Pin the pi version for reproducible builds.
# Build with --build-arg PI_VERSION=x.y.z to override; empty = latest.
ARG PI_VERSION=

# Rust toolchain version for rustup. "stable" by default;
# build with --build-arg RUST_VERSION=1.90.0 to pin.
ARG RUST_VERSION=stable

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

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN uv python install 3.13

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
