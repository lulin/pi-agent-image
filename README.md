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