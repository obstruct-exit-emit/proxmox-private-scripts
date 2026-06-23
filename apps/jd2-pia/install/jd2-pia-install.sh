#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/pia-foss/manual-connections

set -euo pipefail

APP="JDownloader2 + PIA"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-jd2-pia.log}"
mkdir -p "$(dirname "$INSTALL_LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$INSTALL_LOG"; }

YW=$(printf '\033[33m')
GN=$(printf '\033[1;92m')
RD=$(printf '\033[01;31m')
CL=$(printf '\033[m')
BFR='\r\033[K'
TAB='  '
CM="${TAB}✔️${TAB}"
CROSS="${TAB}✖️${TAB}"

msg_info()  { printf '%b\n' "${TAB}${YW}◌${CL} ${1}..."; }
msg_ok()    { printf "${BFR}${CM}${GN}%s${CL}\n" "${1}"; }
msg_error() { printf "${BFR}${CROSS}${RD}%s${CL}\n" "${1}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

msg_info "Updating OS"
apt-get update -qq >> "$INSTALL_LOG" 2>&1 || msg_error "apt-get update failed"
apt-get upgrade -y -qq >> "$INSTALL_LOG" 2>&1 || msg_error "apt-get upgrade failed"
msg_ok "OS updated"

msg_info "Installing dependencies"
apt-get install -y -qq \
  curl \
  ca-certificates \
  default-jre-headless \
  wireguard-tools \
  iptables \
  iproute2 \
  jq >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to install dependencies"
msg_ok "Installed dependencies"

msg_info "Downloading JDownloader2"
mkdir -p /opt/jdownloader2/{config,downloads,cfg}
curl -fsSL "http://installer.jdownloader.org/JDownloader.jar" -o /opt/jdownloader2/JDownloader.jar \
  >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to download JDownloader2"
msg_ok "Downloaded JDownloader2"

msg_info "Pre-enabling Event Scripter and Scheduler extensions"
printf '%s\n' '{"enabled": true}' >/opt/jdownloader2/cfg/org.jdownloader.extensions.eventscripter.EventScripterExtension.json
printf '%s\n' '{"enabled": true}' >/opt/jdownloader2/cfg/org.jdownloader.extensions.schedule.ScheduleExtension.json
msg_ok "Pre-enabled Event Scripter and Scheduler extensions"

msg_info "Fetching PIA manual-connections scripts"
mkdir -p /opt/pia-manual-connections
curl -fsSL "https://codeload.github.com/pia-foss/manual-connections/tar.gz/refs/heads/master" \
  -o /tmp/manual-connections.tar.gz >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to download manual-connections"
tar -xzf /tmp/manual-connections.tar.gz -C /opt/pia-manual-connections --strip-components=1 \
  >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to extract manual-connections"
rm -f /tmp/manual-connections.tar.gz
chmod +x /opt/pia-manual-connections/*.sh
msg_ok "Fetched PIA manual-connections scripts"

msg_info "Writing PIA connect/disconnect helpers"
mkdir -p /etc/pia

cat <<'SCRIPT' >/usr/local/bin/pia-connect.sh
#!/usr/bin/env bash
set -uo pipefail

CRED_FILE="/etc/pia/credentials.env"
LOG="/var/log/pia-connect.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

ROUTE_TABLE=51820
RULE_PRIORITY=100

lockdown() {
  local fwmark="$1"
  iptables -F
  iptables -P INPUT DROP
  iptables -P OUTPUT DROP
  iptables -P FORWARD DROP
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -i pia -j ACCEPT
  iptables -A OUTPUT -o pia -j ACCEPT
  if [[ -n "$fwmark" && "$fwmark" != "off" ]]; then
    iptables -A OUTPUT -m mark --mark "$fwmark" -j ACCEPT
  fi
}

if [[ ! -f "$CRED_FILE" ]]; then
  log "No credentials at $CRED_FILE yet — run pia-setup.sh first. Leaving network open."
  exit 0
fi

# shellcheck disable=SC1090
source "$CRED_FILE"

cd /opt/pia-manual-connections || { log "manual-connections directory missing"; exit 1; }

# network-online.target can fire before DNS/routing is actually usable on boot
# (common LXC/DHCP race) — wait for real reachability before attempting to connect.
for i in $(seq 1 15); do
  getent hosts www.privateinternetaccess.com >/dev/null 2>&1 && break
  sleep 2
done

CONNECTED=0
for attempt in 1 2 3; do
  if PIA_USER="$PIA_USER" PIA_PASS="$PIA_PASS" VPN_PROTOCOL=wireguard DISABLE_IPV6=yes \
     AUTOCONNECT=true PIA_PF=false PIA_DNS=true \
     ./run_setup.sh >> "$LOG" 2>&1 \
     && ip link show pia >/dev/null 2>&1; then
    CONNECTED=1
    break
  fi
  log "Connection attempt ${attempt} failed, retrying in 5s"
  sleep 5
done

if [[ "$CONNECTED" -eq 1 ]]; then
  FWMARK=$(wg show pia fwmark 2>/dev/null)
  # Lower the tunnel MTU to avoid PMTU blackholing: the default WireGuard MTU
  # assumes a full 1500-byte path, which the LXC veth/bridge path often can't
  # carry. Oversized packets then get silently dropped (ICMP "frag needed" is
  # commonly blocked) instead of triggering a retry — large transfers stall
  # partway through while small requests (DNS, API calls) keep working fine.
  ip link set mtu 1280 dev pia
  # The wg kernel module's own encrypted UDP transport must keep using the real
  # default route (eth0) to actually reach the PIA server — only traffic NOT
  # carrying that fwmark gets pushed through a separate table pointed at pia.
  # This mirrors wg-quick's own full-tunnel routing technique.
  ip route replace default dev pia table "$ROUTE_TABLE"
  ip rule del priority "$RULE_PRIORITY" 2>/dev/null || true
  if [[ -n "$FWMARK" && "$FWMARK" != "off" ]]; then
    ip rule add not fwmark "$FWMARK" table "$ROUTE_TABLE" priority "$RULE_PRIORITY"
  else
    ip rule add table "$ROUTE_TABLE" priority "$RULE_PRIORITY"
  fi
  printf '%s\n' "nameserver 1.1.1.1" "nameserver 8.8.8.8" >/etc/resolv.conf
  lockdown "$FWMARK"
  log "Connected, routed normal traffic via pia (table $ROUTE_TABLE, fwmark $FWMARK kept on eth0), and locked down"
  exit 0
else
  log "Connection attempt failed — applying fail-closed lockdown"
  lockdown ""
  exit 1
fi
SCRIPT
chmod +x /usr/local/bin/pia-connect.sh

cat <<'SCRIPT' >/usr/local/bin/pia-disconnect.sh
#!/usr/bin/env bash
set -uo pipefail

iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F

ip rule del priority 100 2>/dev/null || true
ip route flush table 51820 2>/dev/null || true

if ip link show pia >/dev/null 2>&1; then
  ip link set pia down 2>/dev/null || true
  ip link delete pia 2>/dev/null || true
fi

dhclient -r eth0 2>/dev/null || true
dhclient eth0 2>/dev/null || true
SCRIPT
chmod +x /usr/local/bin/pia-disconnect.sh

cat <<'SCRIPT' >/usr/local/bin/pia-setup.sh
#!/usr/bin/env bash
set -euo pipefail

read -rp "PIA username: " PIA_USER
read -rsp "PIA password: " PIA_PASS
echo

mkdir -p /etc/pia
printf "PIA_USER='%s'\nPIA_PASS='%s'\n" "$PIA_USER" "$PIA_PASS" >/etc/pia/credentials.env
chmod 600 /etc/pia/credentials.env
echo "Credentials saved in plain text to /etc/pia/credentials.env (root-only, chmod 600) — review with: cat /etc/pia/credentials.env"

echo "Connecting to PIA..."
if systemctl restart pia-wireguard.service; then
  echo "PIA connected and kill switch active."
else
  echo "PIA connection failed — network is locked down (fail-closed). Check /var/log/pia-connect.log" >&2
fi

systemctl restart jdownloader2.service
echo "JDownloader2 restarted under the current network state."
SCRIPT
chmod +x /usr/local/bin/pia-setup.sh

cat <<'SCRIPT' >/usr/local/bin/pia-reconnect.sh
#!/usr/bin/env bash
set -uo pipefail
echo "Reconnecting to PIA for a fresh exit IP..."
systemctl restart pia-wireguard.service
SCRIPT
chmod +x /usr/local/bin/pia-reconnect.sh

msg_ok "Wrote PIA connect/disconnect/setup/reconnect helpers"

msg_info "Creating PIA systemd service"
cat <<EOF >/etc/systemd/system/pia-wireguard.service
[Unit]
Description=PIA WireGuard tunnel + kill switch
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=8

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/pia-connect.sh
ExecStop=/usr/local/bin/pia-disconnect.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q pia-wireguard.service
msg_ok "PIA service installed (will connect once pia-setup.sh has run)"

msg_info "Creating JDownloader2 service"
cat <<EOF >/etc/systemd/system/jdownloader2.service
[Unit]
Description=JDownloader2 Service
After=pia-wireguard.service
Requires=pia-wireguard.service

[Service]
Type=simple
WorkingDirectory=/opt/jdownloader2
ExecStart=/usr/bin/java -Djava.awt.headless=true -jar /opt/jdownloader2/JDownloader.jar -norestart
SyslogIdentifier=JDownloader2
User=root
Restart=always
RestartSec=10
Environment=HOME=/opt/jdownloader2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now jdownloader2.service
msg_ok "JDownloader2 service enabled and started (unprotected until pia-setup.sh runs)"

cat <<'SCRIPT' >/usr/local/bin/jd2-setup.sh
#!/usr/bin/env bash
set -uo pipefail

echo "Stopping the background JDownloader2 service so we can run it attached to this console..."
systemctl stop jdownloader2.service

cd /opt/jdownloader2 || exit 1
echo
echo "Starting JDownloader2 in the foreground."
echo "It may exit and relaunch a few times while it self-updates before showing the MyJDownloader login prompt — that's normal, just wait."
echo "Once you've logged in and JDownloader2 is running normally, press Ctrl+C to hand it back to the background service."
echo

STOP=0
trap 'STOP=1' INT

while [[ "$STOP" -eq 0 ]]; do
  java -Djava.awt.headless=true -jar JDownloader.jar -norestart
  [[ "$STOP" -eq 1 ]] && break
  echo "JDownloader2 exited — relaunching in 3s (press Ctrl+C now if you're already done)..."
  sleep 3
done

echo
echo "Restarting the managed background service..."
systemctl start jdownloader2.service
echo "Done. Check https://my.jdownloader.org to confirm this device shows up under My Devices."
SCRIPT
chmod +x /usr/local/bin/jd2-setup.sh
msg_ok "Wrote jd2-setup.sh (run after pia-setup.sh to pair with MyJDownloader)"

cat <<'SCRIPT' >/usr/local/bin/jd2-pia-update
#!/usr/bin/env bash
set -euo pipefail
curl -fsSL "https://codeload.github.com/pia-foss/manual-connections/tar.gz/refs/heads/master" \
  -o /tmp/manual-connections.tar.gz
tar -xzf /tmp/manual-connections.tar.gz -C /opt/pia-manual-connections --strip-components=1
rm -f /tmp/manual-connections.tar.gz
chmod +x /opt/pia-manual-connections/*.sh
systemctl restart pia-wireguard.service
echo "PIA manual-connections scripts updated. JDownloader2 self-updates on its own each run."
SCRIPT
chmod +x /usr/local/bin/jd2-pia-update
msg_ok "Installed update helper"

msg_ok "JDownloader2 + PIA installation complete"
