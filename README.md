# lewdity-docker

> [Degrees of Lewdity] is a free and open-source text-based erotic RPG game that takes place in a town somewhere in the UK. Go to school and find honest work, turn to a life of crime, or sell your body in more carnal ways.
>
> The game has strong sexual themes, and lots of sex in general. It is inappropriate for minors. By downloading, you confirm that you are an adult.

This game runs entirely as a clientside SPA (Single Page Application) on a web browser. This means that it can be run from a local file system, or served from any static web server. This Docker image is a simple way to host the game files in a Docker container, allowing the game to be loaded on any web browser with access to the network.

This repository serves as a simple deployment method for the game files in case you'd like to host it on a web server. The game files are served by [`dol-server`], which also syncs save files between devices.

## Usage

The design is very Human, simply run the following command:

```bash
docker run -d \
  --name lewdity \
  -p 8080:80 \
  -v lewdity-saves:/data \
  ghcr.io/korewachino/lewdity-docker
```

This will run the container in detached mode, mapping port 8080 on the host to port 80 on the container. You can then access the game by going to `http://localhost:8080` in your web browser.

The same thing applies to Docker Compose, you can use the [`docker-compose.yml`](docker-compose.yml) in this repository:

```yaml
services:
    lewdity:
        ports:
            - 8080:80
        image: ghcr.io/korewachino/lewdity-docker
        volumes:
            - lewdity-saves:/data

volumes:
    lewdity-saves:
```

`docker compose up` pulls the published image. To build it yourself instead, run `docker compose up --build`. Set `GAME_VERSION` to build a specific game release (it defaults to `master`):

```bash
GAME_VERSION=0.5.12.13 docker compose up --build
```

### Saves

Save files are stored in `/data`, which **must be mounted as a volume**. If you don't, your saves are lost every time the container is recreated.

The game syncs its autosave to the server and back, so the same save is available from any device that opens the game. When two devices disagree, the newest save wins; if it can't tell, the game asks which one to keep.

There is no authentication. Anyone who can reach the container can read and overwrite the save, so don't expose it to the open internet. Keep it on a LAN or a private network such as [Tailscale].

## Building

This image is built using the [`Containerfile`](Containerfile) in the root of the repository. You can build it using the following command:

```bash
docker build -f Containerfile -t lewdity .
```

This will build the image and tag it as `lewdity`. You can then run the image using the same command as above.

With [Podman](https://podman.io/) it's even shorter, as it detects the `Containerfile` automatically:

```bash
podman build -t lewdity .
```

## License

This game is licensed under CC-BY-NC-SA 4.0. You can find the source code here: <https://gitgud.io/Vrelnir/degrees-of-lewdity>

This repository is licensed under the GPL-3.0, matching [`dol-server`], which the image builds and ships.

[Degrees of Lewdity]: https://www.vrelnir.com/
[`dol-server`]: https://github.com/diamondburned/dol-server
[Tailscale]: https://tailscale.com/
