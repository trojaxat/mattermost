FROM alpine:3.19

ARG MM_VERSION=9.7.3
ARG MM_EDITION=team
ARG MM_BINARY=""
ARG PUID=2000
ARG PGID=2000

ENV PATH="/mattermost/bin:${PATH}" \
    MM_VERSION="${MM_VERSION}" \
    MM_EDITION="${MM_EDITION}"

RUN apk add --no-cache \
        ca-certificates \
        curl \
        jq \
        libc6-compat \
        libffi-dev \
        linux-headers \
        mailcap \
        netcat-openbsd \
        tar \
        tzdata \
        xmlsec-dev \
    && update-ca-certificates \
    && mkdir -p \
        /mattermost/data \
        /mattermost/plugins \
        /mattermost/client/plugins \
        /mattermost/config \
        /mattermost/logs

# Download and install Mattermost
RUN set -eux; \
    if [ -n "${MM_BINARY}" ]; then \
        curl -fL "${MM_BINARY}" | tar -xz --strip-components=1 -C /mattermost; \
    elif [ "${MM_EDITION}" = "team" ]; then \
        curl -fL \
          "https://releases.mattermost.com/${MM_VERSION}/mattermost-team-${MM_VERSION}-linux-amd64.tar.gz" \
          | tar -xz --strip-components=1 -C /mattermost; \
    else \
        curl -fL \
          "https://releases.mattermost.com/${MM_VERSION}/mattermost-${MM_VERSION}-linux-amd64.tar.gz" \
          | tar -xz --strip-components=1 -C /mattermost; \
    fi; \
    test -x /mattermost/bin/mattermost; \
    if [ -f /mattermost/config/config.json ]; then \
        cp /mattermost/config/config.json /config.json.save; \
        rm -f /mattermost/config/config.json; \
    fi; \
    addgroup -g "${PGID}" mattermost; \
    adduser -D -u "${PUID}" -G mattermost -h /mattermost mattermost; \
    chown -R mattermost:mattermost /mattermost; \
    if [ -f /config.json.save ]; then \
        chown mattermost:mattermost /config.json.save; \
    fi

# Install MinIO client for the entrypoint script
RUN curl -fL \
      "https://dl.min.io/client/mc/release/linux-amd64/mc" \
      -o /usr/local/bin/mc \
    && chmod 0755 /usr/local/bin/mc

COPY --chown=mattermost:mattermost entrypoint.sh /entrypoint.sh

RUN chmod 0755 /entrypoint.sh

USER mattermost
WORKDIR /mattermost

EXPOSE 8065

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mattermost", "--config", "/tmp/config.json"]
