# SmartStamm Add-ons

Home Assistant add-on repository of ASKÖ Linz-Stamm.

- **SmartStamm Netzmessung**: hourly Speedtest.net (official Ookla CLI against a fixed server, default LIWEST Linz) and hourly RTR-Netztest (RMBT client of the Austrian regulator), each reported as Home Assistant sensors. See `netzmessung/DOCS.md`.

Add this repository in Home Assistant under Settings → Add-ons → Add-on store → ⋮ → Repositories:
`https://github.com/flowsworld/smartstamm-addons`

## Building

There is no prebuilt image and no CI: the Supervisor builds the add-on on the device (the Dockerfile only adds the run script). Both measurement clients are downloaded at first start. Test locally with

```
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base:3.22 -t netzmessung netzmessung
docker run --rm -e SUPERVISOR_TOKEN=x -v <dir>:/data netzmessung
```

with an `options.json` and an empty file `dry_run` in `<dir>`; sensor payloads are then printed instead of sent.

## RMBT client binary

The RTR client is compiled from `rtr-nettest/open-rmbt-client-cli` (`clientRust`, Apache-2.0) at a pinned commit and attached to a release of this repository (`rmbt-client-<commit>`, asset `rmbt-client-aarch64` plus `.sha256`). Build it on an arm64 machine with Docker:

```
docker build --platform linux/arm64 -o type=local,dest=out -f - . <<'EOF2'
FROM rust:1-alpine AS build
RUN apk add --no-cache musl-dev git
ARG RMBT_COMMIT=8d85b82786abacb361c75a496df118d9ac6e3c87
RUN git clone https://github.com/rtr-nettest/open-rmbt-client-cli /src \
 && cd /src && git checkout -q "${RMBT_COMMIT}" \
 && cd clientRust && cargo build --release && strip target/release/rmbt-client
FROM scratch
COPY --from=build /src/clientRust/target/release/rmbt-client /rmbt-client
EOF2
```

Then `gh release create rmbt-client-<short commit> out/rmbt-client#rmbt-client-aarch64` and update `RMBT_RELEASE` and `RMBT_SHA256` in `netzmessung/run.sh`.

Former add-ons `rtr-netztest` and `speedtest-ookla` (up to 2026-09-16) were merged into this one; their images on ghcr.io are no longer used.
