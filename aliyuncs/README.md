# aliyuncs/ — Dockerfiles for ACR cloud builders

Equivalent versions of the layered Dockerfiles in [build/](../build), meant to
be built by the ACR builder service so no image data is ever *pushed* across
the border. ACR builders (including overseas ones) can reach upstream sources
fine, so **the build-time defaults here are upstream, same as build/** — no
mirrors during building. Mirrors are only written by the **patch layer** of
`pi-agent` as *runtime* configuration, exactly as in build/.

What this variant adds over build/:

| | |
|-|-|
| `BASE_IMAGE` defaults | fully-qualified ACR refs (`registry.cn-hangzhou.aliyuncs.com/lulinw/deven:latest`, `.../pi-vanilla:latest`) so the builders chain images via ACR tags |
| override hooks | optional args to point any download at a mirror if a builder ever lacks overseas access: `APT_MIRROR` (none), `NODE_DIST_URL` (nodejs.org), `UV_INSTALLER_GITHUB_BASE_URL` (github.com), `UV_PYTHON_INSTALL_MIRROR` (empty), `RUSTUP_DIST_SERVER`/`RUSTUP_UPDATE_ROOT` (static.rust-lang.org; mainland alt: rsproxy.cn), `NPM_REGISTRY` (empty) |
| layer order | in `pi-agent` only, the npm-registry patch runs before the extensions layer so baked-in `pi install npm:...` benefits; everything else identical |

Runtime configuration (entrypoint, mirrors written into the final image, …)
is identical to build/.

## Builder matrix

Create one ACR builder (云端构建 / build rule) per image, all with the same
GitHub repo as code source:

| # | Repo | Dockerfile path | Context | Tag rule | Optional build args |
|-|-|-|-|-|-|
| 1 | `<ns>/deven` | `aliyuncs/deven/Dockerfile` | repo root | `latest`, `v{major}`… | `NODE_VERSION`, `UV_VERSION`, `RUST_VERSION`, mirror overrides |
| 2 | `<ns>/pi-vanilla` | `aliyuncs/pi-vanilla/Dockerfile` | repo root | `latest` (+ pi version) | `PI_VERSION` (defaults baked in) |
| 3 | `<ns>/pi-agent` | `aliyuncs/pi-agent/Dockerfile` | repo root | `latest` (+ pi version) | `PI_PACKAGES`, runtime mirrors `APT_MIRROR`/`PIP_MIRROR`/`CARGO_MIRROR`/`NPM_MIRROR` |

Defaults are already correct, so builders 1–3 work with **no args
configured**; only set builder arguments when you need different values.

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
