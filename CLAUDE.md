# trueconf-compose

Docker Compose deployment bundle for TrueConf Server. The goal is to prepare a
self-contained release archive on a machine with internet access, then ship it
to a server that has **no internet access** and run `install.sh` there.

## Layout

- `docker-compose.yml` — single `server` service running the TrueConf Server
  image. Uses `network_mode: host` (see "Known quirks") and mounts `./data`
  into the container at `/opt/trueconf/server/var/lib`.
- `.env` / `.env.example` — runtime config (gitignored except the example):
  - `TC_IMAGE_TAG` — full image ref (`trueconf/trueconf-server:<tag>`), written
    automatically by `prepare.sh`.
  - `ADMIN_USER`, `ADMIN_PASSWORD` — admin credentials.
- `install.sh` — run on the **target** server. Idempotent install/upgrade:
  bootstraps Docker/docker-compose from `docker-deps/*.deb` if missing,
  stops existing containers, removes old `trueconf*` images, loads
  `images/*.tar`, optionally imports a DB dump, then `docker-compose up -d`.
- `images/` — holds the offline-loadable image tarball (`trueconf.tar`).
  Gitignored except `.gitkeep`; populated by `prepare.sh`.
- `docker-deps/` — holds `docker.io` + `docker-compose` and their full
  dependency closure as `.deb` files, for bootstrapping Docker itself on a
  target server with no internet access. Gitignored except `.gitkeep`;
  populated by `prepare-docker-deps.sh`. Built for **Debian 12, amd64** —
  re-run against a different base image if the target server differs.
- `data/` — runtime state (bind-mounted into the container). Gitignored
  except `.gitkeep`; created on demand by `install.sh`.
- `.idea/sh/` — tooling scripts (see below), also wired up as IntelliJ run
  configurations under `.idea/runConfigurations/`.
- `.idea/release/` — output folder for packaged release archives. Gitignored
  except `.gitkeep` (archives are large binaries and shouldn't be committed).
- `guides/` — standalone operational docs, e.g. `MIGRATIION_GUIDE_WINDOWS.md`
  (migrating a Windows TrueConf Server install to this Docker setup via a
  `pg_dumpall` dump).

## Scripts (`.idea/sh/`)

- **`prepare.sh`** — run on the dev machine (needs `curl`, `jq`, `fzf`,
  internet, `docker`). Lets you interactively pick a `trueconf/trueconf-server`
  tag from Docker Hub via `fzf`, then `docker pull`s it, `docker save`s it to
  `images/trueconf.tar`, and writes `TC_IMAGE_TAG` into `.env`.
- **`prepare-docker-deps.sh`** — run on the dev machine (needs `docker`,
  internet). Spins up a throwaway `debian:12` (`linux/amd64`) container,
  `apt-get install --download-only`s `docker.io` + `docker-compose`, and
  saves the resulting `.deb` files (full dependency closure) to
  `docker-deps/`.
- **`release.sh`** — runs `prepare.sh` and `prepare-docker-deps.sh`, then
  tars up exactly `images/`, `docker-deps/`, `.env`, `docker-compose.yml`,
  `install.sh` into `.idea/release/trueconf-release-<timestamp>.tar.gz`.
  This archive is the thing that gets copied to the air-gapped server.
  Exposed as the "Release" IntelliJ run configuration.
- **`clear-data.sh`** — wipes everything under `data/` (except `.gitkeep`).
  Used to reset to a fresh install state, e.g. before reinitializing from a
  DB dump.
- **`tunnel.sh`** — opens `ssh -L 8080:127.0.0.1:80` to the production host
  (`root@185.221.199.222`), so `http://localhost:8080` reaches the remote
  server's HTTP port without exposing it publicly.

## Install flow on the target server

1. Extract the release archive; edit `.env` to set real credentials/interface.
2. (Optional) drop a single `pg_dumpall` export into `data/dump/` to seed the
   database on first boot.
3. Run `./install.sh`. If `docker`/`docker-compose` aren't already installed,
   it installs them from `docker-deps/*.deb` first (requires `apt-get`, i.e.
   a Debian/Ubuntu-family target). It then validates `images/trueconf.tar` +
   `.env` exist, swaps in the new image, starts the stack, and — if a dump
   was staged and this is a fresh install (no pre-existing `data/database`)
   — waits for the container's first-boot setup and imports the dump
   automatically.

## Known quirks

- `docker-compose.yml` sources the container's `ADMIN_USER` env var from the
  host env var `ADMIN_LOGIN` (`ADMIN_USER=${ADMIN_LOGIN:-admin}`), but `.env`
  defines `ADMIN_USER` instead of `ADMIN_LOGIN`. As written, the admin login
  always falls back to the default `admin` — `.env`'s `ADMIN_USER` value is
  not actually wired through. Only `ADMIN_PASSWORD` is correctly picked up.
- `docker-compose.yml` uses `network_mode: host` instead of publishing
  individual ports — TrueConf's realtime media (WebRTC/RTP) needs a wide,
  effectively dynamic UDP port range beyond 80/443/4307, which isn't
  practical to enumerate with Docker's `ports:` mapping. The tradeoff: the
  container now shares the host's network namespace directly, so there's no
  compose-level way to restrict it to one interface (`PRIMARY_INTERFACE` no
  longer exists/applies) — any interface restriction has to happen via the
  host firewall or the application's own bind-address config, if it has one.
  `network_mode: host` is Linux-only, which is fine for the Debian 12
  target but means this compose file won't run the same way under Docker
  Desktop on macOS/Windows.
