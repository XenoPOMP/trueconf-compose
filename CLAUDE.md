# trueconf-compose

Docker Compose deployment bundle for TrueConf Server. The goal is to prepare a
self-contained release archive on a machine with internet access, then ship it
to a server that has **no internet access** and run `install.sh` there.

## Layout

- `docker-compose.yml` — single `server` service running the TrueConf Server
  image. Binds ports 80/443/4307 to `${PRIMARY_INTERFACE}` and mounts `./data`
  into the container at `/opt/trueconf/server/var/lib`.
- `.env` / `.env.example` — runtime config (gitignored except the example):
  - `TC_IMAGE_TAG` — full image ref (`trueconf/trueconf-server:<tag>`), written
    automatically by `prepare.sh`.
  - `ADMIN_USER`, `ADMIN_PASSWORD` — admin credentials.
  - `PRIMARY_INTERFACE` — host interface/IP to bind the published ports to.
- `install.sh` — run on the **target** server. Idempotent install/upgrade:
  stops existing containers, removes old `trueconf*` images, loads
  `images/*.tar`, optionally imports a DB dump, then `docker-compose up -d`.
- `images/` — holds the offline-loadable image tarball (`trueconf.tar`).
  Gitignored except `.gitkeep`; populated by `prepare.sh`.
- `data/` — runtime state (bind-mounted into the container). Gitignored
  except `.gitkeep`; created on demand by `install.sh`.
- `.idea/sh/` — tooling scripts (see below), also wired up as IntelliJ run
  configurations under `.idea/runConfigurations/`.
- `.idea/release/` — output folder for packaged release archives. Gitignored
  except `.gitkeep` (archives are large binaries and shouldn't be committed).

## Scripts (`.idea/sh/`)

- **`prepare.sh`** — run on the dev machine (needs `curl`, `jq`, `fzf`,
  internet, `docker`). Lets you interactively pick a `trueconf/trueconf-server`
  tag from Docker Hub via `fzf`, then `docker pull`s it, `docker save`s it to
  `images/trueconf.tar`, and writes `TC_IMAGE_TAG` into `.env`.
- **`release.sh`** — runs `prepare.sh`, then tars up exactly
  `images/`, `.env`, `docker-compose.yml`, `install.sh` into
  `.idea/release/trueconf-release-<timestamp>.tar.gz`. This archive is the
  thing that gets copied to the air-gapped server. Exposed as the "Release"
  IntelliJ run configuration.
- **`clear-data.sh`** — wipes everything under `data/` (except `.gitkeep`).
  Used to reset to a fresh install state, e.g. before reinitializing from a
  DB dump.

## Install flow on the target server

1. Extract the release archive; edit `.env` to set real credentials/interface.
2. (Optional) drop a single `pg_dumpall` export into `data/dump/` to seed the
   database on first boot.
3. Run `./install.sh`. It validates `images/trueconf.tar` + `.env` exist,
   swaps in the new image, starts the stack, and — if a dump was staged and
   this is a fresh install (no pre-existing `data/database`) — waits for the
   container's first-boot setup and imports the dump automatically.

## Known quirks

- `docker-compose.yml` sources the container's `ADMIN_USER` env var from the
  host env var `ADMIN_LOGIN` (`ADMIN_USER=${ADMIN_LOGIN:-admin}`), but `.env`
  defines `ADMIN_USER` instead of `ADMIN_LOGIN`. As written, the admin login
  always falls back to the default `admin` — `.env`'s `ADMIN_USER` value is
  not actually wired through. Only `ADMIN_PASSWORD` is correctly picked up.
- `.env.example` defaults `PRIMARY_INTERFACE` to `127.0.0.1`; the real `.env`
  in this checkout uses `0.0.0.0` — double check this before shipping a
  release, since it controls which interface the server is exposed on.
