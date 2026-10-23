ARG GAME_VERSION=master
ARG SOURCE=https://gitgud.io/Vrelnir/degrees-of-lewdity.git
ARG DOL_SERVER_REF=0c2cfd3c62b512ea5dca297d35d7b71ba5fefe62
ARG ESBUILD_VERSION=0.25.5
ARG GO_VERSION=1.21

FROM node:latest AS builder

ARG GAME_VERSION
ARG SOURCE

RUN git clone --depth 1 --branch ${GAME_VERSION} ${SOURCE} /app

WORKDIR /app

RUN npm install
RUN ./compile.sh

# Compile dol-server, the Go server that serves the game and syncs saves.
# Pinned to a commit because upstream has no release tags.
FROM golang:${GO_VERSION} AS dol-server-builder

ARG DOL_SERVER_REF

RUN git clone https://github.com/diamondburned/dol-server /src \
 && cd /src && git checkout ${DOL_SERVER_REF}

WORKDIR /src
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/dol-server .

# Bundle dol-server's extension JS.
# Upstream uses `deno bundle`, but that was removed in Deno 2 and the Deno
# runtime is winding down, so we use Node + esbuild instead. `deno bundle` was
# itself an esbuild wrapper, so the output is equivalent.
FROM node:22-bookworm-slim AS dol-server-js-builder

ARG ESBUILD_VERSION=0.25.5

WORKDIR /bundle
RUN npm install --no-save --silent esbuild@${ESBUILD_VERSION}

COPY --from=dol-server-builder /src/extension extension
COPY --from=dol-server-builder /src/lib lib

COPY scripts/build-autosync.mjs build.mjs

RUN node build.mjs

FROM dol-server-builder AS dol-server-final

# dol-server embeds this file with go:embed. Overwriting upstream's committed
# copy with our freshly bundled output keeps the Go build deterministic and
# independent of upstream's checked-in artifacts.
COPY --from=dol-server-js-builder /bundle/out/autosync_generated.js extension/autosync/autosync_generated.js
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/dol-server .

# The runtime image: alpine + dol-server. No Caddy; dol-server serves the game
# files and handles save syncing itself.
FROM alpine:latest

ARG GAME_VERSION

LABEL org.opencontainers.image.licenses="CC-BY-NC-SA-4.0 AND GPL-3.0-only"
LABEL org.opencontainers.image.url="https://www.vrelnir.com/"
LABEL org.opencontainers.image.authors="Vrelnir <vrelnir@gmail.com>, Cappy Ishihara <cappy@cappuchino.xyz>"

RUN apk add --no-cache ca-certificates

COPY --from=dol-server-final /out/dol-server /usr/local/bin/dol-server

RUN mkdir -p /app
COPY --from=builder /app/*.html /app
COPY --from=builder /app/img /app/img

WORKDIR /app
# dol-server requires exactly one HTML file in the game directory, so the
# duplicate copies have to go.
# The thing is, the game symlinks "Degrees of Lewdity.html" to "Degrees of Lewdity ${GITSHA}.html",
# but when we copy files over, it follows the symlink resulting in two copies of the same file.
# So we need to remove the symlink and the duplicate file.
RUN find /app -name "Degrees of Lewdity *.html" -type f -delete

# Saves live here and must be mounted as a volume, otherwise they are lost
# whenever the container is recreated.
VOLUME ["/data"]

COPY dol-server.json /etc/dol-server/dol-server.json

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/dol-server"]
CMD ["-l", ":80", "-c", "/etc/dol-server/dol-server.json"]

# aand that's it, enjoy