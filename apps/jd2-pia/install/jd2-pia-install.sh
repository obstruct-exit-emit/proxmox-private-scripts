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
mkdir -p /opt/jdownloader2/{config,downloads}
curl -fsSL "http://installer.jdownloader.org/JDownloader.jar" -o /opt/jdownloader2/JDownloader.jar \
  >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to download JDownloader2"
msg_ok "Downloaded JDownloader2"

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

lockdown() {
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
}

if [[ ! -f "$CRED_FILE" ]]; then
  log "No credentials at $CRED_FILE yet — run pia-setup.sh first. Leaving network open."
  exit 0
fi

# shellcheck disable=SC1090
source "$CRED_FILE"

cd /opt/pia-manual-connections || { log "manual-connections directory missing"; exit 1; }

if PIA_USER="$PIA_USER" PIA_PASS="$PIA_PASS" VPN_PROTOCOL=wireguard DISABLE_IPV6=yes \
   AUTOCONNECT=true PIA_PF=false PIA_DNS=true \
   ./run_setup.sh >> "$LOG" 2>&1 \
   && ip link show pia >/dev/null 2>&1; then
  lockdown
  log "Connected and locked down via pia interface"
  exit 0
else
  log "Connection attempt failed — applying fail-closed lockdown"
  lockdown
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

if ip link show pia >/dev/null 2>&1; then
  ip link set pia down 2>/dev/null || true
  ip link delete pia 2>/dev/null || true
fi
SCRIPT
chmod +x /usr/local/bin/pia-disconnect.sh

cat <<'SCRIPT' >/usr/local/bin/pia-setup.sh
#!/usr/bin/env bash
set -euo pipefail

read -rp "PIA username: " PIA_USER
read -rsp "PIA password: " PIA_PASS
echo

mkdir -p /etc/pia
printf 'PIA_USER=%q\nPIA_PASS=%q\n' "$PIA_USER" "$PIA_PASS" >/etc/pia/credentials.env
chmod 600 /etc/pia/credentials.env

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
msg_ok "Wrote PIA connect/disconnect/setup helpers"

msg_info "Creating PIA systemd service"
cat <<EOF >/etc/systemd/system/pia-wireguard.service
[Unit]
Description=PIA WireGuard tunnel + kill switch
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/pia-connect.sh
ExecStop=/usr/local/bin/pia-disconnect.sh

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
