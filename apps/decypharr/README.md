# Decypharr

Standalone Proxmox VE helper script for installing [Decypharr](https://github.com/sirrobot01/decypharr) in an LXC container.

## Files

- `ct/decypharr.sh` — host-side LXC creation entrypoint used by the bootstrap loader
- `install/decypharr-install.sh` — self-contained in-container installer and service setup

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/decypharr.sh?nocache=$(date +%s)")"
```

The `?nocache=$(date +%s)` busts GitHub's CDN cache (it can serve a stale copy for a few minutes after a push) — keep it when testing right after pushing a change.

The host-side script copies `install/decypharr-install.sh` into the container and runs it from `/root`, so the installer is intentionally standalone and does not source repo-relative files from `lib/`.

The container's console (`pct console <CTID>`) is configured to auto-login as root, so no password is needed there either; `pct enter <CTID>` already bypasses login entirely.

## Defaults

| Setting | Default |
|---------|---------|
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 2048 MB |
| Disk | 8 GB |
| Network | DHCP on `vmbr0` |
| Port | 8282 |
| Install path | `/opt/decypharr` |
| Upstream | `sirrobot01/decypharr` |
| Update helper | true |
