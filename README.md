# SmartStamm Add-ons

Home Assistant add-on repository of ASKÖ Linz-Stamm.

- **RTR-Netztest**: runs the Austrian regulator's RTR-Netztest (RMBT) on a schedule and reports download, upload and ping as Home Assistant sensors.
- **Speedtest.net (Ookla CLI)**: runs the official Ookla CLI against a fixed Speedtest.net server (default LIWEST Linz) on a schedule and reports download, upload and ping as Home Assistant sensors.

Add this repository in Home Assistant under Settings → Add-ons → Add-on store → ⋮ → Repositories:
`https://github.com/flowsworld/smartstamm-addons`

## Building images

Only RTR-Netztest uses a prebuilt image (its client is compiled from Rust). Speedtest.net has no `image` entry and is built by the Supervisor on the device; test it locally with `docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base:3.22 speedtest-ookla`.

RTR-Netztest images are built by the manual workflow **Build add-on images** (Actions → Run workflow, choose `aarch64`, `amd64` or both). The workflow does not run on push. Before starting it, test the Dockerfile locally with `docker build rtr-netztest`.
