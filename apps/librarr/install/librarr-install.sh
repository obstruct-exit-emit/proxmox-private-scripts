#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/JeremiahM37/librarr

set -euo pipefail

APP="Librarr"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-librarr.log}"
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

download_first_working_asset() {
  local destination="$1"
  shift
  local url
  for url in "$@"; do
    if curl -fsSL --location "$url" -o "$destination"; then
      return 0
    fi
  done
  return 1
}

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
  ca-certificates >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to install dependencies"
msg_ok "Installed dependencies"

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64) ASSET_ARCH="amd64" ;;
  arm64) ASSET_ARCH="arm64" ;;
  *) msg_error "Unsupported architecture: $ARCH" ;;
esac
log "Architecture: $ARCH"

msg_info "Looking up latest release"
LATEST=$(curl -fsSL "https://api.github.com/repos/JeremiahM37/librarr/releases/latest" \
  | grep '"tag_name"' | head -1 | grep -Po '"tag_name":\s*"\K[^"]+' || true)
[[ -z "$LATEST" ]] && msg_error "Could not determine latest Librarr release"
VERSION_NO_V="${LATEST#v}"
log "Latest release: $LATEST"
msg_ok "Latest release: ${LATEST}"

ASSET_CANDIDATES=(
  "https://github.com/JeremiahM37/librarr/releases/download/${LATEST}/librarr_${VERSION_NO_V}_linux_${ASSET_ARCH}.tar.gz"
  "https://github.com/JeremiahM37/librarr/releases/latest/download/librarr_linux_${ASSET_ARCH}.tar.gz"
)

msg_info "Downloading Librarr"
mkdir -p /opt/librarr
TMP=$(mktemp -d)
if ! download_first_working_asset "${TMP}/librarr.tar.gz" "${ASSET_CANDIDATES[@]}" >> "$INSTALL_LOG" 2>&1; then
  msg_error "No compatible release asset found for architecture: $ARCH"
fi
msg_ok "Downloaded Librarr"

msg_info "Installing Librarr"
tar -xzf "${TMP}/librarr.tar.gz" -C "${TMP}" >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to extract archive"

BINARY=$(find "${TMP}" -maxdepth 2 -type f -name "librarr" | head -1)
[[ -z "$BINARY" ]] && msg_error "librarr binary not found in archive"

cp "$BINARY" /opt/librarr/librarr
chmod +x /opt/librarr/librarr
echo "$LATEST" >/opt/librarr/VERSION
rm -rf "${TMP}"
msg_ok "Installed Librarr ${LATEST}"

msg_info "Creating data directories"
mkdir -p /opt/librarr/data/incoming /opt/librarr/data/manga-incoming
mkdir -p /mnt/librarr/{ebooks,audiobooks,manga}
msg_ok "Created data directories"

msg_info "Writing default config"
# head -c 16 reads a bounded amount from /dev/urandom and exits on its own,
# so od never gets SIGPIPE'd — unlike `tr ... </dev/urandom | head -c N`,
# where head closing early kills tr with SIGPIPE (exit 141), which
# `set -o pipefail` then treats as a hard failure.
API_KEY=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
TORZNAB_API_KEY=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')

cat <<EOF >/opt/librarr/librarr.env
# Server
LIBRARR_PORT=5050
LIBRARR_DB_PATH=/opt/librarr/data/librarr.db
SETTINGS_FILE=/opt/librarr/data/settings.json

# Authentication — leave AUTH_USERNAME/AUTH_PASSWORD blank to register the
# first admin account from the web UI instead (recommended). API_KEY and
# TORZNAB_API_KEY below were generated at install time.
AUTH_USERNAME=
AUTH_PASSWORD=
API_KEY=${API_KEY}
TORZNAB_API_KEY=${TORZNAB_API_KEY}

# File organization
EBOOK_DIR=/mnt/librarr/ebooks
AUDIOBOOK_DIR=/mnt/librarr/audiobooks
MANGA_DIR=/mnt/librarr/manga
INCOMING_DIR=/opt/librarr/data/incoming
MANGA_INCOMING_DIR=/opt/librarr/data/manga-incoming

# Torrent download client — set TORRENT_CLIENT to "qbittorrent" or
# "transmission" once one is configured below (empty = auto-detect).
TORRENT_CLIENT=
QB_URL=
QB_USER=admin
QB_PASS=
QB_SAVE_PATH=/downloads
QB_CATEGORY=librarr
QB_AUDIOBOOK_SAVE_PATH=/audiobooks-incoming
QB_AUDIOBOOK_CATEGORY=audiobooks
QB_MANGA_SAVE_PATH=/manga-incoming
QB_MANGA_CATEGORY=manga
TRANSMISSION_URL=
TRANSMISSION_USER=
TRANSMISSION_PASS=

# Usenet
SABNZBD_URL=
SABNZBD_API_KEY=
SABNZBD_CATEGORY=librarr

# Prowlarr (optional — torrent indexer search)
PROWLARR_URL=
PROWLARR_API_KEY=

# Library import targets — see
# https://github.com/JeremiahM37/librarr#configuration for the full list.
CALIBRE_LIBRARY_PATH=
CALIBRE_URL=
ABS_URL=
ABS_TOKEN=
ABS_LIBRARY_ID=
ABS_EBOOK_LIBRARY_ID=
KAVITA_URL=
KAVITA_USER=
KAVITA_PASS=
KAVITA_LIBRARY_PATH=
KAVITA_MANGA_LIBRARY_PATH=
KOMGA_URL=
KOMGA_USER=
KOMGA_PASS=
KOMGA_LIBRARY_ID=
KOMGA_LIBRARY_PATH=
EOF
chmod 600 /opt/librarr/librarr.env
msg_ok "Config written"

msg_info "Creating service"
cat <<EOF >/etc/systemd/system/librarr.service
[Unit]
Description=Librarr Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/librarr
EnvironmentFile=/opt/librarr/librarr.env
ExecStart=/opt/librarr/librarr
SyslogIdentifier=Librarr
User=root
Restart=always
RestartSec=5
NoNewPrivileges=true
Environment=HOME=/opt/librarr
Environment=UMASK=022

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now librarr
msg_ok "Service enabled and started"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/librarr.sh)"' \
  >/usr/local/bin/librarr-update
chmod +x /usr/local/bin/librarr-update
msg_ok "Installed update helper"

msg_ok "Librarr installation complete"
