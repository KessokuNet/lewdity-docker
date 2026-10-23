ARG GAME_VERSION=master
ARG SOURCE=https://gitgud.io/Vrelnir/degrees-of-lewdity.git

FROM node:latest as builder

ARG GAME_VERSION
ARG SOURCE

RUN git clone --depth 1 --branch ${GAME_VERSION} ${SOURCE} /app

WORKDIR /app

RUN npm install
RUN ./compile.sh

FROM caddy:latest

LABEL org.opencontainers.image.licenses="CC-BY-NC-SA-4.0"
LABEL org.opencontainers.image.url="https://www.vrelnir.com/"
LABEL org.opencontainers.image.authors="Vrelnir <vrelnir@gmail.com>, Cappy Ishihara <cappy@cappuchino.xyz>"

RUN mkdir -p /app
COPY --from=builder /app/*.html /app
COPY --from=builder /app/img /app/img

WORKDIR /app
# Remove duplicate files
# The thing is, the game symlinks "Degrees of Lewdity.html" to "Degrees of Lewdity ${GITSHA}.html",
# but when we copy files over to the caddy image, it follows the symlink resulting in two copies of the same file.
# So we need to remove the symlink and the duplicate file.
RUN find /app -name "Degrees of Lewdity *.html" -type f -delete

# Now we symlink the file to "index.html" so that caddy can serve it as the default page.
RUN ln -s "Degrees of Lewdity.html" "index.html"

COPY Caddyfile /etc/caddy/Caddyfile

# aand that's it, enjoy getting molested by the tutorial molester
