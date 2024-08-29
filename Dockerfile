# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS builder

COPY scripts/start-homepage.sh /scripts/

ARG HOMEPAGE_VERSION

# hadolint ignore=SC1091,SC3044
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Set up node. \
    && source "${NVM_DIR:?}/nvm.sh" \
    # Install build dependencies. \
    && homelab install git \
    && mkdir -p /root/homepage /root/homepage-deps \
    # Download homepage repo. \
    && homelab download-git-repo \
        https://github.com/gethomepage/homepage \
        ${HOMEPAGE_VERSION:?} \
        /root/homepage \
    # Set up dependencies first. \
    && pushd /root/homepage-deps \
    && cp /root/homepage/{package.json,package-lock.json} . \
    && npm ci --omit=dev --omit=optional --no-audit --no-fund --no-update-notifier \
    && npm install \
    && popd \
    # Build homepage. \
    && pushd /root/homepage \
    && cp -rf /root/homepage-deps/node_modules . \
    && npm run telemetry \
    && NEXT_PUBLIC_BUILDTIME="$(date "+%FT%T.%3N%z")" \
        NEXT_PUBLIC_VERSION="${HOMEPAGE_VERSION:?}" \
        NEXT_PUBLIC_REVISION="$(git rev-parse --verify HEAD)" \
        npm run build \
    # Copy the build artifacts. \
    && cp -rf ./.next/standalone /release \
    && cp -rf ./.next/static /release/.next/static \
    && cp ./package.json ./next.config.js /release/ \
    && cp -rf ./public /release/ \
    # Copy the startup script. \
    && cp /scripts/start-homepage.sh /release/ \
    && popd

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG HOMEPAGE_VERSION

# hadolint ignore=SC3040
RUN --mount=type=bind,target=/build,from=builder,source=/release \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --no-create-home-dir \
    && cp -rf /build /opt/homepage-${HOMEPAGE_VERSION#v} \
    && ln -sf /opt/homepage-${HOMEPAGE_VERSION#v} /opt/homepage \
    && ln -sf /opt/homepage/start-homepage.sh /opt/bin/start-homepage \
    && chown -R ${USER_NAME}:${GROUP_NAME:?} /opt/homepage-${HOMEPAGE_VERSION#v}

EXPOSE 3000

HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD homelab healthcheck-service http://localhost:3000/api/healthcheck

ENV NODE_ENV=production
ENV WUD_VERSION="$HOMEPAGE_VERSION"

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-homepage"]
STOPSIGNAL SIGTERM
