# JDownloader2 + PIA

Standalone Proxmox VE helper script for installing [JDownloader2](http://www.jdownloader.org/) in an LXC container with its traffic routed through a [Private Internet Access](https://www.privateinternetaccess.com/) WireGuard tunnel, using PIA's official [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) scripts and a hand-rolled iptables kill switch.

## Files

- `ct/jd2-pia.sh` — host-side LXC creation entrypoint used by the bootstrap loader
- `install/jd2-pia-install.sh` — self-contained in-container installer and service setup

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/jd2-pia.sh)"
```

The host-side script copies `install/jd2-pia-install.sh` into the container and runs it from `/root`, so the installer is intentionally standalone and does not source repo-relative files from `lib/`.

The container's console (`pct console <CTID>`) is configured to auto-login as root, so no password is needed there either; `pct enter <CTID>` already bypasses login entirely.

PIA credentials are never passed to the installer or baked into the image. Once the container is up, finish setup manually:

```bash
pct enter <CTID>
pia-setup.sh
```

`pia-setup.sh` prompts for your PIA username/password, writes them to `/etc/pia/credentials.env` (root-only), brings up the WireGuard tunnel via `run_setup.sh`, and applies the kill switch. Then pair this JDownloader2 instance at [my.jdownloader.org](https://my.jdownloader.org) (no MyJDownloader credentials are scripted either — pair it manually from the container).

## How the kill switch works

`manual-connections` doesn't ship kill switch rules itself, so this app adds its own via `/usr/local/bin/pia-connect.sh` (run by `pia-wireguard.service` on every boot):

1. If `/etc/pia/credentials.env` doesn't exist yet, it's a no-op and leaves the network open — this is the state before you've ever run `pia-setup.sh`.
2. Otherwise it brings the tunnel up over the container's normal, unrestricted network (needed to authenticate against PIA), then locks down with iptables (`DROP` on INPUT/OUTPUT/FORWARD except loopback, established/related, and the `pia` interface) only once the tunnel is confirmed live.
3. If a reconnect ever fails after credentials already exist, it fails closed (full lockdown) rather than leaking traffic on the real IP.

**Known limitations:**

- **JDownloader2 has no VPN protection until `pia-setup.sh` is run once.** The service starts immediately at install time on the container's normal network so the install doesn't hang waiting for credentials that don't exist yet.
- This is a "connect first, then lock down" pattern, not a sub-second race-proof kill switch — it favors not permanently bricking your own first-time setup over absolute leak-proofing during the brief boot window.
- `pct exec` / `pct enter` from the Proxmox host always works regardless of the container's own iptables state (it operates at the LXC level), so a failed-closed container is still recoverable.
- WireGuard inside an **unprivileged** LXC depends on the Proxmox host kernel having WireGuard support (default on modern PVE kernels). If `run_setup.sh` can't bring up the `pia` interface, check `/var/log/pia-connect.log` inside the container.

## Defaults

| Setting | Default |
|---------|---------|
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 2048 MB |
| Disk | 8 GB |
| Network | DHCP on `vmbr0` |
| Access | No exposed port — managed via [my.jdownloader.org](https://my.jdownloader.org) pairing |
| JD2 install path | `/opt/jdownloader2` |
| PIA scripts path | `/opt/pia-manual-connections` |
| VPN protocol | WireGuard |
| Upstream | `pia-foss/manual-connections` |
| Update helper | `jd2-pia-update` (re-pulls manual-connections scripts; JD2 self-updates on its own) |
