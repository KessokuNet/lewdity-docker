ARG GAME_VERSION=master
ARG SOURCE=https://gitgud.io/Vrelnir/degrees-of-lewdity.git
ARG VANILLA_SOURCE=https://gitgud.io/Vrelnir/degrees-of-lewdity.git
ARG DOL_SERVER_REF=0c2cfd3c62b512ea5dca297d35d7b71ba5fefe62
ARG ESBUILD_VERSION=0.25.5
ARG GO_VERSION=1.21

FROM node:latest AS builder

ARG GAME_VERSION
ARG SOURCE
ARG VANILLA_SOURCE

RUN apt-get update \
 && apt-get install -y --no-install-recommends git-lfs \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${GAME_VERSION} ${SOURCE} /app

WORKDIR /app

# Some forks keep assets in Git LFS (DoLX stores audio/ there), which a plain
# clone leaves as pointer files. LFS zips are release archives we never ship.
RUN git lfs install --local && git lfs pull --exclude="*.zip"

RUN npm install
RUN ./compile.sh

# Forks can be missing vanilla images their code still uses (DoLX 0.22.3
# deleted weather banners and clouds it still loads). Fetch the vanilla
# release the fork is based on, named by the first word of its version file,
# so its images can go underneath the fork's.
RUN if [ "${SOURCE}" != "${VANILLA_SOURCE}" ]; then \
      base="$(cut -d' ' -f1 version)" \
      && echo "Overlaying onto vanilla ${base} images" \
      && git clone --depth 1 --branch "${base}" --filter=blob:none --sparse \
           "${VANILLA_SOURCE}" /vanilla \
      && git -C /vanilla sparse-checkout set img; \
    fi

# Collect what the game needs at runtime. compile.sh makes
# "Degrees of Lewdity.html" a symlink to the versioned build; dol-server wants
# exactly one HTML file, so copy just that one with the link resolved.
# img2/, audio/ and imagepacks/ only exist in some forks (e.g. DoLX).
# Vanilla images (if fetched above) go first so the fork's own files win.
RUN mkdir /dist \
 && cp -L "Degrees of Lewdity.html" /dist/ \
 && if [ -d /vanilla/img ]; then cp -r /vanilla/img /dist/; fi \
 && for dir in img img2 audio imagepacks; do \
      if [ -d "$dir" ]; then mkdir -p "/dist/$dir" && cp -r "$dir/." "/dist/$dir/"; fi; \
    done

# Compile dol-server, the Go server that serves the game and syncs saves.
# Pinned to a commit because upstream has no release tags.
FROM golang:${GO_VERSION} AS dol-server-builder

ARG DOL_SERVER_REF

RUN git clone https://github.com/diamondburned/dol-server /src \
 && cd /src && git checkout ${DOL_SERVER_REF}

WORKDIR /src

# Our fixes on top of upstream dol-server; see patches/dol-server/
COPY patches/dol-server /patches
RUN git apply --verbose /patches/*.patch

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

COPY --from=builder /dist /app

WORKDIR /app

# Saves live here and must be mounted as a volume, otherwise they are lost
# whenever the container is recreated.
VOLUME ["/data"]

COPY dol-server.json /etc/dol-server/dol-server.json

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/dol-server"]
CMD ["-l", ":80", "-c", "/etc/dol-server/dol-server.json"]

# aand that's it, enjoy