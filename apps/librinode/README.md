# LibriNode

Standalone Proxmox VE helper script for installing [LibriNode](https://github.com/obstruct-exit-emit/LibriNode) in an LXC container, built from source (clones the git repo and compiles the Go binary with embedded React UI).

LibriNode is a self-hosted written-media automation server (the Readarr / LazyLibrarian successor) — handles ebooks, audiobooks, manga, comics, and magazines with *arr-style integrations for Prowlarr, qBittorrent, and SABnzbd.

## Files

- `ct/librinode.sh` — host-side LXC creation entrypoint used by the bootstrap loader; also doubles as the in-container update routine when `pveversion` is absent
- `install/librinode-install.sh` — self-contained in-container installer: installs Node.js, Go 1.25, clones the repo, builds the web UI and binary, and creates the systemd service

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/librinode.sh?nocache=$(date +%s)")"
```

The `?nocache=$(date +%s)` busts GitHub's CDN cache (it can serve a stale copy for a few minutes after a push) — keep it when testing right after pushing a change.

The host-side script copies `install/librinode-install.sh` into the container and runs it from `/root`, so the installer is intentionally standalone and does not source repo-relative files from `lib/`.

The container's console (`pct console <CTID>`) is configured to auto-login as root, so no password is needed there either; `pct enter <CTID>` already bypasses login entirely.

## First run

1. Open `http://<container-ip>:7845` and complete the first-run setup wizard (create an admin account, no API key required).
2. Navigate to **Settings → Metadata** and add your Hardcover API token (get one at [hardcover.app/account/api](https://hardcover.app/account/api)) — this enables book/audiobook metadata search.
3. **Settings → Media Management → Root Folders**: add one root folder per media type you want to manage (ebooks, audiobooks, manga, comics, magazines) — these map to `/mnt/librinode/{ebooks,audiobooks,manga,comics,magazines}` by default (you can bind-mount your actual media into those paths from the Proxmox host, or reconfigure the folders in the UI).
4. **Settings → Download Clients**: wire up qBittorrent and/or SABnzbd.
5. **Settings → Indexers**: either connect to Prowlarr (application sync) or manually add Newznab/Torznab indexers.

## Updating to latest git version

Inside the container, run:

```bash
update
```

This pulls the latest commit from `main`, rebuilds the web UI and binary, and restarts the service. Your data directory (`/opt/librinode/data` — contains `config.yaml`, `librinode.db`, cover art cache, and logs) is untouched, so no data loss.

## Defaults

| Setting | Default |
|---------|---------|
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 2048 MB |
| Disk | 8 GB |
| Network | DHCP on `vmbr0` |
| Port | 7845 |
| Source repo | `/opt/librinode-src` (cloned from `obstruct-exit-emit/LibriNode`) |
| Binary | `/usr/local/bin/librinode` |
| Data path | `/opt/librinode/data` |
| Media dirs | `/mnt/librinode/{ebooks,audiobooks,manga,comics,magazines}` |
| Upstream | `obstruct-exit-emit/LibriNode` |
| Update command | `update` (installed at `/usr/local/bin/update`) |

## Build requirements

- **Node.js 22+** (for web UI build via `npm`)
- **Go 1.25+** (for backend binary; installed from `go.dev/dl/` since Debian's golang-go may lag behind)
- **Git** (for clone and updates)

All dependencies are installed automatically by the installer script.
