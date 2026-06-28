# Librarr

Standalone Proxmox VE helper script for installing [Librarr](https://github.com/JeremiahM37/librarr) in an LXC container, using the upstream release binary directly (no Docker).

Librarr is a self-hosted book/audiobook/manga search and download manager (the *arr equivalent for books) — a single static Go binary with zero CGO dependencies and an embedded pure-Go SQLite driver.

## Files

- `ct/librarr.sh` — host-side LXC creation entrypoint used by the bootstrap loader; also doubles as the in-container update routine
- `install/librarr-install.sh` — self-contained in-container installer and service setup

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/librarr.sh?nocache=$(date +%s)")"
```

The `?nocache=$(date +%s)` busts GitHub's CDN cache (it can serve a stale copy for a few minutes after a push) — keep it when testing right after pushing a change.

The host-side script copies `install/librarr-install.sh` into the container and runs it from `/root`, so the installer is intentionally standalone and does not source repo-relative files from `lib/`.

The container's console (`pct console <CTID>`) is configured to auto-login as root, so no password is needed there either; `pct enter <CTID>` already bypasses login entirely.

## First run

1. Open `http://<container-ip>:5050` and register the first admin account from the web UI (the installer leaves `AUTH_USERNAME`/`AUTH_PASSWORD` blank on purpose so multi-user registration handles this).
2. Edit `/opt/librarr/librarr.env` inside the container to wire up a torrent client (qBittorrent or Transmission), Prowlarr, and any library targets (Calibre, Audiobookshelf, Kavita, Komga), then `systemctl restart librarr`.
3. A random `API_KEY` and `TORZNAB_API_KEY` are generated at install time and stored in `/opt/librarr/librarr.env` (root-only, `chmod 600`).

## Updating

Run `librarr-update` inside the container, or re-run the bootstrap one-liner from the host targeting the existing container's shell. It compares the installed version (tracked in `/opt/librarr/VERSION`, since the binary has no `--version` flag) against the latest GitHub release and swaps the binary in place if newer.

## Defaults

| Setting | Default |
|---------|---------|
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 1024 MB |
| Disk | 8 GB |
| Network | DHCP on `vmbr0` |
| Port | 5050 |
| Install path | `/opt/librarr` |
| Data path | `/opt/librarr/data` |
| Library dirs | `/mnt/librarr/{ebooks,audiobooks,manga}` |
| Upstream | `JeremiahM37/librarr` |
| Update helper | true |
