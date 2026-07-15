#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/obstruct-exit-emit/LibriNode

set -euo pipefail

APP="LibriNode"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-librinode.log}"
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
  git \
  curl \
  ca-certificates \
  nodejs \
  npm >> "$INSTALL_LOG" 2>&1 || msg_error "Failed to install dependencies"
msg_ok "Installed base dependencies"

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64) GO_ARCH="amd64" ;;
  arm64) GO_ARCH="arm64" ;;
  *) msg_error "Unsupported architecture: $ARCH" ;;
esac
log "Architecture: $ARCH"

msg_info "Installing Go 1.25"
GO_VERSION="1.25.1"
GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
curl -fsSL "https://go.dev/dl/${GO_TARBALL}" -o "/tmp/${GO_TARBALL}" >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to download Go ${GO_VERSION}"
rm -rf /usr/local/go
tar -C /usr/local -xzf "/tmp/${GO_TARBALL}" >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to extract Go"
rm -f "/tmp/${GO_TARBALL}"
export PATH="/usr/local/go/bin:$PATH"
echo 'export PATH="/usr/local/go/bin:$PATH"' >> /etc/profile.d/go.sh
msg_ok "Installed Go $(go version | awk '{print $3}')"

msg_info "Cloning LibriNode repository"
git clone https://github.com/obstruct-exit-emit/LibriNode.git /opt/librinode-src >> "$INSTALL_LOG" 2>&1 \
  || msg_error "Failed to clone repository"
cd /opt/librinode-src || msg_error "Failed to cd to source directory"
COMMIT=$(git rev-parse --short HEAD)
log "Cloned at commit: $COMMIT"
msg_ok "Cloned repository (${COMMIT})"

msg_info "Building web UI"
cd web || msg_error "web/ directory not found"
npm ci --silent >> "$INSTALL_LOG" 2>&1 || msg_error "npm ci failed"
npm run build --silent >> "$INSTALL_LOG" 2>&1 || msg_error "npm build failed"
msg_ok "Built web UI"

msg_info "Building LibriNode binary"
cd /opt/librinode-src || exit 1
CGO_ENABLED=0 go build -trimpath \
  -ldflags "-s -w -X main.version=$(git describe --tags --always --dirty)" \
  -o /usr/local/bin/librinode ./cmd/librinode >> "$INSTALL_LOG" 2>&1 \
  || msg_error "go build failed"
chmod +x /usr/local/bin/librinode
msg_ok "Built LibriNode binary"

msg_info "Creating data directories"
mkdir -p /opt/librinode/data
mkdir -p /mnt/librinode/{ebooks,audiobooks,manga,comics,magazines}
msg_ok "Created data directories"

msg_info "Creating systemd service"
cat <<'EOF' >/etc/systemd/system/librinode.service
[Unit]
Description=LibriNode written-media automation server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/librinode --data /opt/librinode/data
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
Environment=PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now librinode
msg_ok "Service enabled and started"

msg_info "Installing update command"
cat <<'UPDATESCRIPT' >/usr/local/bin/update
#!/usr/bin/env bash
set -euo pipefail

YW=$(printf '\033[33m')
GN=$(printf '\033[1;92m')
RD=$(printf '\033[01;31m')
CL=$(printf '\033[m')
BFR='\r\033[K'
TAB='  '
CM="${TAB}✔️${TAB}"

msg_info()  { printf '%b\n' "${TAB}${YW}◌${CL} ${1}..."; }
msg_ok()    { printf "${BFR}${CM}${GN}%s${CL}\n" "${1}"; }
msg_error() { printf "${BFR}${TAB}✖️${TAB}${RD}%s${CL}\n" "${1}"; exit 1; }

export PATH="/usr/local/go/bin:$PATH"

if [[ ! -d /opt/librinode-src ]]; then
  msg_error "LibriNode source directory not found"
fi

msg_info "Checking for updates"
cd /opt/librinode-src || msg_error "Failed to cd to source directory"

git fetch origin main >/dev/null 2>&1
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [[ "$LOCAL" == "$REMOTE" ]]; then
  msg_ok "Already up to date ($(git rev-parse --short HEAD))"
  exit 0
fi

msg_info "Stopping service"
systemctl stop librinode
msg_ok "Stopped service"

msg_info "Pulling latest changes"
git pull origin main >/dev/null 2>&1 || msg_error "git pull failed"
NEW_COMMIT=$(git rev-parse --short HEAD)
msg_ok "Pulled ${NEW_COMMIT}"

msg_info "Building web UI"
cd web || msg_error "web/ directory not found"
npm ci --silent >/dev/null 2>&1 || msg_error "npm ci failed"
npm run build --silent >/dev/null 2>&1 || msg_error "npm build failed"
msg_ok "Built web UI"

msg_info "Building LibriNode binary"
cd /opt/librinode-src || exit 1
CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=$(git describe --tags --always --dirty)" \
  -o /usr/local/bin/librinode ./cmd/librinode >/dev/null 2>&1 || msg_error "go build failed"
chmod +x /usr/local/bin/librinode
msg_ok "Built binary"

msg_info "Starting service"
systemctl start librinode
msg_ok "Started service"
msg_ok "Updated successfully to ${NEW_COMMIT}"
UPDATESCRIPT
chmod +x /usr/local/bin/update
msg_ok "Installed update command"

msg_ok "LibriNode installation complete"
