# Decypharr

Standalone Proxmox VE helper script for installing [Decypharr](https://github.com/sirrobot01/decypharr) in an LXC container.

## Files

- `ct/decypharr.sh` — host-side LXC creation entrypoint
- `install/decypharr-install.sh` — in-container installer and service setup

## Usage

Run the one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/decypharr/ct/decypharr.sh)"
```

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
