# Shelfmark

Standalone Proxmox VE helper script for installing [your Shelfmark fork](https://github.com/obstruct-exit-emit/shelfmark) in an LXC container, built from source via Docker.

## Files

- `ct/shelfmark.sh` — host-side LXC creation entrypoint used by the bootstrap loader
- `install/shelfmark-install.sh` — self-contained in-container installer and service setup

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/shelfmark.sh?nocache=$(date +%s)")"
```

The `?nocache=$(date +%s)` busts GitHub's CDN cache (it can serve a stale copy for a few minutes after a push) — keep it when testing right after pushing a change.

The host-side script copies `install/shelfmark-install.sh` into the container and runs it from `/root`, so the installer is intentionally standalone and does not source repo-relative files from `lib/`.

The container's console (`pct console <CTID>`) is configured to auto-login as root, so no password is needed there either; `pct enter <CTID>` already bypasses login entirely.

## How this differs from the upstream compose file

Shelfmark's own `compose/docker-compose.yml` pulls a prebuilt image (`ghcr.io/calibrain/shelfmark:latest`) — that's the *upstream* project's image, not anything built from this fork, since the fork hasn't published its own image to GHCR. To actually run your fork's code, the installer instead:

1. `git clone`s `obstruct-exit-emit/shelfmark` into `/opt/shelfmark/src`
2. Writes its own `/opt/shelfmark/docker-compose.yml` with `build: /opt/shelfmark/src` (using the repo's own `Dockerfile`) instead of an `image:` reference
3. Runs `docker compose up -d --build`, so Docker builds the image locally from your fork's current `main` branch

Volumes are bound to `/opt/shelfmark/books` and `/opt/shelfmark/config` (both `chown`'d to `1000:1000` to match the container's default `PUID`/`PGID`) instead of the placeholder paths in the upstream example.

`shelfmark-update` (and the bootstrap one-liner re-run on a non-Proxmox host) does `git pull --ff-only` in `/opt/shelfmark/src` followed by `docker compose up -d --build`, so updating always rebuilds from whatever is currently on your fork's `main` branch.

## Networking

Runs on the container's normal network — no VPN/kill switch, unlike `jd2-pia`. Shelfmark searches and requests metadata/books rather than doing bulk anonymous downloading itself, so that complexity didn't seem worth it here; ask if you want it routed through PIA too.

## Defaults

| Setting | Default |
|---------|---------|
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 3072 MB |
| Disk | 12 GB |
| Network | DHCP on `vmbr0` |
| Port | 8084 |
| Source | `/opt/shelfmark/src` (your fork, `main` branch) |
| Books/config | `/opt/shelfmark/books`, `/opt/shelfmark/config` |
| Upstream | `obstruct-exit-emit/shelfmark` |
| Update helper | `shelfmark-update` (git pull + docker compose rebuild) |
