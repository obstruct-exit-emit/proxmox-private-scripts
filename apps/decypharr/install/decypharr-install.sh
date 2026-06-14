#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/sirrobot01/decypharr

set -euo pipefail

APP="Decypharr"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-decypharr.log}"
mkdir -p "$(dirname "$INSTALL_LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$INSTALL_LOG"; }

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../../.." && pwd)
# shellcheck source=lib/output.sh
source "${REPO_ROOT}/lib/output.sh"
# shellcheck source=lib/github.sh
source "${REPO_ROOT}/lib/github.sh"

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
  tar \
  fuse3 \
  ca-certificates \
  sqlite3 >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to install dependencies"
msg_ok "Installed dependencies"

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64)
    ASSET_CANDIDATES=(
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_linux_amd64.tar.gz"
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_linux_x86_64.tar.gz"
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_linux_x64.tar.gz"
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_amd64_linux.tar.gz"
    )
    ;;
  arm64)
    ASSET_CANDIDATES=(
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_linux_arm64.tar.gz"
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_linux_aarch64.tar.gz"
      "https://github.com/sirrobot01/decypharr/releases/latest/download/decypharr_arm64_linux.tar.gz"
    )
    ;;
  *) msg_error "Unsupported architecture: $ARCH" ;;
esac
log "Architecture: $ARCH"

msg_info "Downloading Decypharr"
mkdir -p /opt/decypharr
TMP=$(mktemp -d)
if ! download_first_working_asset "${TMP}/decypharr.tar.gz" "${ASSET_CANDIDATES[@]}" >> "$INSTALL_LOG" 2>&1; then
  msg_error "No compatible release asset found for architecture: $ARCH"
fi
msg_ok "Downloaded Decypharr"

msg_info "Installing Decypharr"
tar -xzf "${TMP}/decypharr.tar.gz" -C "${TMP}" >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to extract archive"

BINARY=$(find "${TMP}" -maxdepth 2 -type f -name "decypharr" | head -1)
[[ -z "$BINARY" ]] && msg_error "decypharr binary not found in archive"

cp "$BINARY" /opt/decypharr/decypharr
chmod +x /opt/decypharr/decypharr
rm -rf "${TMP}"
mkdir -p /opt/decypharr/{logs,cache,config}
msg_ok "Installed Decypharr"

msg_info "Creating data directories"
mkdir -p /mnt/decypharr/{downloads,remote,symlinks,temp,completed}
msg_ok "Created data directories"

msg_info "Writing default config"
cat <<'EOF' >/opt/decypharr/config/config.json
{
  "log_level": "info",
  "qbittorrent": {
    "refresh_interval": 60
  },
  "debrids": [],
  "arrs": [],
  "mount": {
    "type": "none"
  }
}
EOF
msg_ok "Config written"

msg_info "Creating service"
cat <<EOF >/etc/systemd/system/decypharr.service
[Unit]
Description=Decypharr Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/decypharr
ExecStart=/opt/decypharr/decypharr --config /opt/decypharr/config
SyslogIdentifier=Decypharr
User=root
Restart=always
RestartSec=5
NoNewPrivileges=true
Environment=HOME=/opt/decypharr
Environment=UMASK=022

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now decypharr
msg_ok "Service enabled and started"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/decypharr.sh)"' \
  >/usr/bin/update
chmod +x /usr/bin/update

msg_ok "Decypharr installation complete"
