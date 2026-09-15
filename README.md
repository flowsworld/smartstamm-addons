# SmartStamm Add-ons

Home Assistant add-on repository of ASKÖ Linz-Stamm.

- **RTR-Netztest**: runs the Austrian regulator's RTR-Netztest (RMBT) on a schedule and reports download, upload and ping as Home Assistant sensors.

Add this repository in Home Assistant under Settings → Add-ons → Add-on store → ⋮ → Repositories:
`https://github.com/flowsworld/smartstamm-addons`

## Building images

Images are built by the manual workflow **Build add-on images** (Actions → Run workflow, choose `aarch64`, `amd64` or both). The workflow does not run on push. Before starting it, test the Dockerfile locally with `docker build rtr-netztest`.
