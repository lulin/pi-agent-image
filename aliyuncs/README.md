# aliyuncs/ — Dockerfiles for ACR cloud builders

These are mainland-network mirrors of the layered Dockerfiles in [build/](../build).
They produce **functionally equivalent images**; the only differences are
build-time source defaults, because the ACR builder service runs inside an
Alibaba Cloud mainland region and must not fetch from overseas:

| Source | build/ default | aliyuncs/ default |
|-|-|-|
| base distro image | `ubuntu:24.04` | same (`BASE_IMAGE` overridable) |
| apt (build-time) | upstream | USTC mirror (`APT_MIRROR=ustc`) |
| Node.js tarballs | nodejs.org | same (`NODE_DIST_URL`; npmmirror exists but its merged `latest-vX.x` listing is stale — see Dockerfile note) |
| uv installer | ghcr.io image copy (`COPY --from=ghcr.io/astral-sh/uv`) | official install.sh with `UV_INSTALLER_GITHUB_BASE_URL=https://gh-proxy.com/https://github.com` |
| uv python builds | GitHub releases | `registry.npmmirror.com/-/binary/python-build-standalone` (`UV_PYTHON_INSTALL_MIRROR`) |
| rustup dist | static.rust-lang.org | `rsproxy.cn` (`RUSTUP_DIST_SERVER` / `RUSTUP_UPDATE_ROOT`) |
| npm (pi install) | registry.npmjs.org | `registry.npmmirror.com` (`NPM_REGISTRY` / `NPM_MIRROR`) |

Runtime configuration (entrypoint, mirrors written into the final image, …)
is identical to build/.

## Builder matrix

Create one ACR builder (云端构建 / build rule) per image, all with the same
GitHub repo as code source:

| # | Repo | Dockerfile path | Context | Tag rule | Key build args |
|-|-|-|-|-|-|
| 1 | `<ns>/deven` | `aliyuncs/deven/Dockerfile` | repo root | `latest`, `v{major}`… | `NODE_VERSION`, `UV_VERSION`, `RUST_VERSION`, `APT_MIRROR` |
| 2 | `<ns>/pi-vanilla` | `aliyuncs/pi-vanilla/Dockerfile` | repo root | `latest` (+ pi version) | `PI_VERSION` (defaults baked in) |
| 3 | `<ns>/pi-agent` | `aliyuncs/pi-agent/Dockerfile` | repo root | `latest` (+ pi version) | `PI_PACKAGES`, `APT_MIRROR`, `PIP_MIRROR`, `CARGO_MIRROR`, `NPM_MIRROR` |

Build-arg defaults are already correct for mainland building, so builders 1–3
work with **no args configured**; only override them in the builder settings
when you need different values.

### Dependency order

Each child image `FROM`s the parent **by tag from ACR**
(`registry.cn-hangzhou.aliyuncs.com/lulinw/...`), so trigger them in order:

```
deven  ->  pi-vanilla  ->  pi-agent
```

* Personal Edition: trigger manually (console "build" button) after the
  parent's latest build succeeds, or use the "code auto-build" rule combined
  with careful timing.
* Enterprise Edition: use 构建规则 with "base image update trigger" (or the
  交付链/delivery chain) to chain them automatically.
* Same-region builders can swap the `BASE_IMAGE` default to the VPC endpoint
  (`registry-vpc.cn-hangzhou.aliyuncs.com/...`) for an internal pull.

### Gotcha: private parent images

The builder service pulls `BASE_IMAGE` from your private namespace; make sure
the build uses your account's credentials (same-account private images are
pulled automatically in the console's builder; if you hit auth errors, set
the parent repos' 摘要信息 to 公开 or configure the builder's credential).
