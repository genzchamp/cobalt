FROM node:24-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

FROM base AS build
WORKDIR /app
COPY . /app

RUN corepack enable
RUN apk add --no-cache python3 alpine-sdk git

# Render's build context may omit .git, but @imput/version-info reads
# Git metadata at runtime. Fetch the fork's metadata into the build stage.
RUN git clone --depth 1 https://github.com/genzchamp/cobalt.git /tmp/cobalt-meta \
    && cp -a /tmp/cobalt-meta/.git /app/.git \
    && rm -rf /tmp/cobalt-meta

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --frozen-lockfile

RUN pnpm deploy --filter=@imput/cobalt-api --prod /prod/api

FROM base AS api
# Refresh the image's trusted CA bundle to address the Render eMudhra advisory.
RUN apk add --no-cache ca-certificates && update-ca-certificates

WORKDIR /app

COPY --from=build --chown=node:node /prod/api /app
COPY --from=build --chown=node:node /app/.git /app/.git

USER node

EXPOSE 9000
CMD [ "node", "src/cobalt" ]
