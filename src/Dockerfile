# https://verdaccio.org/docs/docker/#creating-your-own-dockerfile-using-verdaccioverdacciotag-as-base
# https://github.com/verdaccio/verdaccio/tree/master/docker-examples/v6/plugins/docker-build-install-plugin

ARG VERDACCIO_VERSION=6

# Docker multi-stage build - https://docs.docker.com/develop/develop-images/multistage-build/
FROM node:24 AS builder

# npm docs
# --install-strategy https://docs.npmjs.com/cli/v11/commands/npm-install#install-strategy
# --omit=optional    https://docs.npmjs.com/cli/v11/commands/npm-install#omit
WORKDIR /verdaccio/plugins
RUN set -eux \
  && npm install --global npm@latest \
  && npm install --install-strategy=shallow --omit=optional \
      verdaccio-gitlab@3 \
      verdaccio-aws-s3-storage@10

# The final built image will be based on the standard Verdaccio docker image.
FROM verdaccio/verdaccio:$VERDACCIO_VERSION

COPY config.yaml /verdaccio/conf/config.yaml

# Copy the plugin files over from the 'builder' node image.
# The `$VERDACCIO_USER_UID` env variable is defined in the base `verdaccio/verdaccio` image.
# Refer to: https://github.com/verdaccio/verdaccio/blob/v5.2.0/Dockerfile#L32
COPY --chown=$VERDACCIO_USER_UID:root --from=builder \
  /verdaccio/plugins/node_modules/verdaccio-gitlab \
  /verdaccio/plugins/verdaccio-gitlab
COPY --chown=$VERDACCIO_USER_UID:root --from=builder \
  /verdaccio/plugins/node_modules/verdaccio-aws-s3-storage \
  /verdaccio/plugins/verdaccio-aws-s3-storage


