# Home Assistant base image (bashio, curl, jq). The Ookla CLI binary is not part
# of the image: its EULA does not allow redistribution, so run.sh downloads it
# into the add-on data directory on first start.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.22
FROM ${BUILD_FROM}
COPY run.sh /run.sh
RUN chmod +x /run.sh
ARG BUILD_ARCH
ARG BUILD_VERSION
LABEL io.hass.type="addon" io.hass.arch="${BUILD_ARCH}" io.hass.version="${BUILD_VERSION}" \
      io.hass.name="Speedtest.net (Ookla CLI)" io.hass.description="Scheduled Speedtest.net measurement"
CMD ["/run.sh"]
