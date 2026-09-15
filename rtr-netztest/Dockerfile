# Stage 1: build the RTR RMBT CLI client (Rust) from the upstream repository at a pinned commit
FROM rust:1-alpine AS build
RUN apk add --no-cache musl-dev git
ARG RMBT_COMMIT=8d85b82786abacb361c75a496df118d9ac6e3c87
RUN git clone https://github.com/rtr-nettest/open-rmbt-client-cli /src \
 && cd /src && git checkout -q "${RMBT_COMMIT}" \
 && cd clientRust && cargo build --release \
 && strip target/release/rmbt-client

# Stage 2: Home Assistant base image with bashio, curl and jq
FROM ghcr.io/home-assistant/base:3.22
COPY --from=build /src/clientRust/target/release/rmbt-client /usr/local/bin/rmbt-client
COPY run.sh /run.sh
RUN chmod +x /run.sh
ARG BUILD_ARCH
ARG BUILD_VERSION
LABEL io.hass.type="addon" io.hass.arch="${BUILD_ARCH}" io.hass.version="${BUILD_VERSION}" \
      io.hass.name="RTR-Netztest" io.hass.description="Scheduled RTR-Netztest speed measurement"
CMD ["/run.sh"]
