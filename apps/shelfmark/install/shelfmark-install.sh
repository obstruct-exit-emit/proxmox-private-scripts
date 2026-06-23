#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/obstruct-exit-emit/shelfmark

set -euo pipefail

APP="Shelfmark"
UPSTREAM_REPO="obstruct-exit-emit/shelfmark"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-shelfmark.log}"
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
  git >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to install dependencies"
msg_ok "Installed dependencies"

msg_info "Installing Docker"
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to download Docker install script"
sh /tmp/get-docker.sh >> "$INSTALL_LOG" 2>&1 || msg_error "Docker install failed"
rm -f /tmp/get-docker.sh
systemctl enable -q --now docker
msg_ok "Installed Docker"

msg_info "Cloning ${UPSTREAM_REPO}"
rm -rf /opt/shelfmark/src
git clone --depth 1 "https://github.com/${UPSTREAM_REPO}.git" /opt/shelfmark/src \
  >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to clone ${UPSTREAM_REPO}"
msg_ok "Cloned ${UPSTREAM_REPO}"

msg_info "Preparing application directories"
mkdir -p /opt/shelfmark/config /opt/shelfmark/books
chown -R 1000:1000 /opt/shelfmark/config /opt/shelfmark/books
msg_ok "Prepared application directories"

msg_info "Writing docker-compose.yml"
cat <<'EOF' >/opt/shelfmark/docker-compose.yml
services:
  shelfmark:
    build: /opt/shelfmark/src
    container_name: shelfmark
    environment:
      PUID: 1000
      PGID: 1000
    ports:
      - 8084:8084
    restart: unless-stopped
    volumes:
      - /opt/shelfmark/books:/books
      - /opt/shelfmark/config:/config
EOF
msg_ok "Wrote docker-compose.yml"

msg_info "Building and starting Shelfmark (this can take a few minutes)"
docker compose -f /opt/shelfmark/docker-compose.yml up -d --build \
  >> "$INSTALL_LOG" 2>&1 || msg_error "docker compose up failed — check $INSTALL_LOG"
msg_ok "Shelfmark built and started"

cat <<'SCRIPT' >/usr/local/bin/shelfmark-update
#!/usr/bin/env bash
set -euo pipefail
cd /opt/shelfmark/src
git pull --ff-only
docker compose -f /opt/shelfmark/docker-compose.yml up -d --build
echo "Shelfmark rebuilt and restarted from the latest commit on your fork."
SCRIPT
chmod +x /usr/local/bin/shelfmark-update
msg_ok "Installed update helper"

msg_ok "Shelfmark installation complete"
