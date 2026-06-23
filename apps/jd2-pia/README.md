# JDownloader2 + PIA

Standalone Proxmox VE helper script for installing [JDownloader2](http://www.jdownloader.org/) in an LXC container with its traffic routed through a [Private Internet Access](https://www.privateinternetaccess.com/) WireGuard tunnel, using PIA's official [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) scripts and a hand-rolled iptables kill switch.

## Files

- `ct/jd2-pia.sh` — host-side LXC creation entrypoint used by the bootstrap loader
- `install/jd2-pia-install.sh` — self-contained in-container installer and service setup

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/jd2-pia.sh?nocache=$(date +%s)")"
```

The `?nocache=$(date +%s)` busts GitHub's CDN cache (it can serve a stale copy for a few minutes after a push) — keep it when testing right after pushing a change.

The host-side script copies `install/jd2-pia-install.sh` into the container and runs it from `/root`, so the installer is intentionally standalone and does not source repo-relative files from `lib/`.

The container's console (`pct console <CTID>`) is configured to auto-login as root, so no password is needed there either; `pct enter <CTID>` already bypasses login entirely.

Neither PIA nor MyJDownloader credentials are ever passed to the installer or baked into the image. Once the container is up, finish setup manually:

```bash
pct enter <CTID>
pia-setup.sh
jd2-setup.sh
```

`pia-setup.sh` prompts for your PIA username/password, writes them to `/etc/pia/credentials.env` (root-only), brings up the WireGuard tunnel via `run_setup.sh`, and applies the kill switch.

`jd2-setup.sh` stops the background `jdownloader2.service`, runs JDownloader2 attached to your console, and relaunches it automatically while it self-updates (this can take a few cycles) until it shows the MyJDownloader login prompt. Log in there, then press `Ctrl+C` once it's running normally — the script hands control back to the systemd-managed background service. The account binding is saved under `/opt/jdownloader2/cfg/` and persists across restarts, so this is a one-time step. JDownloader2 can't prompt for this on its own since the background service has no attached console.

To use JDownloader2's built-in Reconnect feature (Settings → Reconnect, a separate category from General — pick the *Custom/Script* method), point it at `/usr/local/bin/pia-reconnect.sh`. It restarts `pia-wireguard.service`, forcing a fresh PIA connection. Since `AUTOCONNECT=true` picks the lowest-latency server each time, this often — but not always — lands on a different exit IP; ask if you want it changed to pick a random region instead for more reliable IP diversity.

## How the kill switch works

`manual-connections` doesn't ship kill switch rules itself, so this app adds its own via `/usr/local/bin/pia-connect.sh` (run by `pia-wireguard.service` on every boot):

1. If `/etc/pia/credentials.env` doesn't exist yet, it's a no-op and leaves the network open — this is the state before you've ever run `pia-setup.sh`.
2. Otherwise it brings the tunnel up over the container's normal, unrestricted network (needed to authenticate against PIA). `manual-connections` only creates the `pia` interface — it deliberately doesn't touch routing or DNS (per its own README).
3. Once the tunnel is live, `pia-connect.sh` routes normal traffic through it **without breaking the tunnel's own transport**: WireGuard's encrypted UDP packets to the PIA server still have to leave via the real `eth0` route to actually reach the internet, so naively replacing the default route kills the tunnel's own keepalives shortly after connecting (the kill switch then blocks them too, and everything dies). Instead it mirrors `wg-quick`'s own full-tunnel technique — a separate routing table (`51820`) with a default route via `pia`, and an `ip rule` that sends everything **except** packets carrying the wg interface's own `fwmark` through that table. Marked (tunnel transport) traffic falls through to the normal table and keeps using `eth0`; everything else (DNS, JDownloader2, etc.) goes through `pia`. `/etc/resolv.conf` is pointed at public resolvers reachable through the tunnel (`1.1.1.1`/`8.8.8.8`), since the original DHCP-provided DNS server is only reachable via `eth0`, which the kill switch blocks for everything but that fwmark.
4. Only after routing is set up does it lock down with iptables (`DROP` on INPUT/OUTPUT/FORWARD except loopback, established/related, the `pia` interface, and outbound traffic carrying the tunnel's own fwmark).
5. On boot, `network-online.target` can fire before DNS/routing is actually usable (a common LXC/DHCP race), so `pia-connect.sh` waits up to 30s for real reachability and retries the connection up to 3 times before giving up; `pia-wireguard.service` itself also retries via `Restart=on-failure` as a second layer. If a reconnect still fails after credentials already exist, it fails closed (full lockdown) rather than leaking traffic on the real IP.
6. `pia-disconnect.sh` (the service's `ExecStop`) tears down iptables, the routing table/rule, and the `pia` interface, then triggers a DHCP renewal on `eth0` to restore normal routing/DNS.

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
