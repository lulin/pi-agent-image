# Pi image builder

This project is for building container images for the well known [Pi](https://pi.dev/)
AI agent and pushing them to any registry. The registry here is Alibaba ACR.

## The hierarchy

- **Base layer**, a linux distro, Alpine Linux is used here
- **Toolchain layer**, python toolchain, node24, rust and so on
- **Vanilla Pi layer**, the Pi agent
- **Pi extensions layer**, extensions for Pi
- **Patch layer**, patch, write configuration files such as setting mirrors of pypi, node and cargo

## Images

The integrated Pi agent harness is divided into layered images.

|Image|Layers|Packages|
|-|-|-|
|deven|Base,Toolchain|Alpine Linux, uv, python-3.14 on uv, node24, rust toolchain|
|pi-vanilla|Vanilla Pi, on deven|Pi|
|pi-agent|Pi extensions, Patch, on pi-vanilla|Pi extensions, patches, configuration files|

## Building

The Dockerfiles live under [build/](./build), one directory per image, and are
chained with the `BASE_IMAGE` build arg:

```bash
docker build -f build/deven/Dockerfile       -t deven:latest .
docker build -f build/pi-vanilla/Dockerfile  --build-arg BASE_IMAGE=deven:latest \
  --build-arg PI_VERSION=0.87.1 -t pi-vanilla:latest .
docker build -f build/pi-agent/Dockerfile    --build-arg BASE_IMAGE=pi-vanilla:latest \
  --build-arg PI_PACKAGES="npm:@foo/bar@1.0.0" -t pi-agent:latest .
```

Images are built and pushed to ACR by the
[GitHub Action](./.github/workflows/build-pi-agent.yml); the local build above
is only for reference. The action uses `docker/login-action` for registry
login and `docker/build-push-action` with per-image registry layer caching.

The patch layer (pi-agent) bakes China-mainland mirrors into configuration
files: build args `APK_MIRROR`, `NPM_MIRROR`, `PIP_MIRROR`, `CARGO_MIRROR`
(`ustc` default, `tuna`/`none` where applicable).
