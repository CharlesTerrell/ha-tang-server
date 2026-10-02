FROM debian:trixie-slim

# Prevent interactive prompts during apt operations
ENV DEBIAN_FRONTEND=noninteractive

# Install Tang server, socat for interface/IP binding, and network/JSON utilities
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tang \
        tang-common \
        socat \
        iproute2 \
        curl \
        jq \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add Home Assistant metadata labels
LABEL \
    io.hass.name="Tang Server" \
    io.hass.description="Network-Bound Disk Encryption (Tang) server for Home Assistant" \
    io.hass.version="1.0.0" \
    io.hass.type="app" \
    io.hass.arch="amd64|aarch64|armv7"

WORKDIR /

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
