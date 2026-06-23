#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/new-app.sh <app-slug> [display-title] [port] [upstream-repo] [update-support]

Arguments:
  app-slug        Required. Folder and script name, e.g. radarr
  display-title   Optional. Human-friendly app title, e.g. qBittorrent
  port            Optional. Default app port, e.g. 7878
  upstream-repo   Optional. GitHub repo in owner/name format, e.g. linuxserver/Heimdall
  update-support  Optional. true or false. Defaults to true
EOF
}

if [[ $# -lt 1 || $# -gt 5 ]]; then
  usage
  exit 1
fi

APP="$1"
APP_TITLE="${2:-$(printf '%s' "$APP" | sed -E 's/(^|-)([a-z])?/\U\2/g')}"
APP_PORT="${3:-8080}"
UPSTREAM_REPO="${4:-owner/repo}"
UPDATE_SUPPORT="${5:-true}"
APP_DIR="apps/${APP}"
BOOTSTRAP_PATH="bootstrap/${APP}.sh"
APP_LOG_SLUG="${APP//[^a-zA-Z0-9_-]/-}"
UPDATE_HELPER_LINE='msg_info "Update helper disabled for this app scaffold"'

case "$UPDATE_SUPPORT" in
  true|false) ;;
  *)
    echo "update-support must be true or false"
    exit 1
    ;;
esac

if [[ "$UPDATE_SUPPORT" == "true" ]]; then
  UPDATE_HELPER_LINE=$(cat <<EOF
printf '%s\\n' \\
  '#!/usr/bin/env bash' \\
  'bash -c "\\$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/${APP}.sh)"' \\
  >/usr/local/bin/${APP}-update
chmod +x /usr/local/bin/${APP}-update
msg_ok "Installed update helper"
EOF
)
fi

mkdir -p "${APP_DIR}/ct" "${APP_DIR}/install" "bootstrap"

cat >"${APP_DIR}/README.md" <<EOF
# ${APP_TITLE}

Standalone Proxmox VE helper script for installing [${APP_TITLE}](https://github.com/${UPSTREAM_REPO}) in an LXC container.

## Files

- \`ct/${APP}.sh\` — host-side LXC creation entrypoint used by the bootstrap loader
- \`install/${APP}-install.sh\` — self-contained in-container installer and service setup

## Usage

Run the bootstrap one-liner below from a Proxmox VE shell:

\`\`\`bash
bash -c "\$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/${APP}.sh)"
\`\`\`

The host-side script copies \`install/${APP}-install.sh\` into the container and runs it from \`/root\`, so the installer is intentionally standalone and does not source repo-relative files from \`lib/\`.

## Defaults

| Setting | Default |
|---------|---------|
| OS | Debian 13 |
| CPU | 2 cores |
| RAM | 2048 MB |
| Disk | 8 GB |
| Network | DHCP on \`vmbr0\` |
| Port | ${APP_PORT} |
| Install path | \`/opt/${APP}\` |
| Upstream | \`${UPSTREAM_REPO}\` |
| Update helper | ${UPDATE_SUPPORT} |
EOF

cat >"${APP_DIR}/ct/${APP}.sh" <<EOF
#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/${UPSTREAM_REPO}

set -euo pipefail

APP="${APP_TITLE}"
APP_SLUG="${APP}"
APP_PORT="${APP_PORT}"
APP_INSTALL_SCRIPT="${APP}-install.sh"
var_tags="\${var_tags:-community}"
var_cpu="\${var_cpu:-2}"
var_ram="\${var_ram:-2048}"
var_disk="\${var_disk:-8}"
var_os="\${var_os:-debian}"
var_version="\${var_version:-13}"
var_unprivileged="\${var_unprivileged:-1}"

SCRIPT_DIR=\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=\$(cd -- "\${SCRIPT_DIR}/../../.." && pwd)
# shellcheck source=lib/output.sh
source "\${REPO_ROOT}/lib/output.sh"
# shellcheck source=lib/common.sh
source "\${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/lxc.sh
source "\${REPO_ROOT}/lib/lxc.sh"
# shellcheck source=lib/github.sh
source "\${REPO_ROOT}/lib/github.sh"

update_script() {
  msg_info "Update path not implemented yet for \${APP}"
  exit 0
}

if ! command -v pveversion >/dev/null 2>&1; then
  update_script
  exit 0
fi

clear
printf '%b\\n' "\${BOLD}\${GN}\n  \${APP} LXC Installer\${CL}"
echo

require_root
require_supported_arch

ARCH=\$(dpkg --print-architecture)
msg_info "Checking storage"
find_storage_pools
msg_ok "Templates on \${TEMPLATE_STORAGE}, containers on \${CONTAINER_STORAGE}"

msg_info "Looking for \${var_os^} \${var_version} template (\${ARCH})"
TEMPLATE=\$(find_latest_template "\${var_os}" "\${var_version}" "\${ARCH}")
[[ -z "\${TEMPLATE}" ]] && msg_error "No \${var_os^} \${var_version} template found for \${ARCH}"
msg_ok "Found template: \${TEMPLATE}"

download_template_if_missing "\${TEMPLATE_STORAGE}" "\${TEMPLATE}"

CTID=\$(next_ctid)
[[ -z "\${CTID}" ]] && msg_error "Could not determine next container ID"
HN="${APP}"

msg_info "Creating LXC container \${CTID} (\${HN})"
create_lxc "\${CTID}" "\${TEMPLATE_STORAGE}" "\${TEMPLATE}" "\${HN}" "community-script;\${var_tags}" "\${var_cpu}" "\${var_ram}" "\${var_disk}" "\${CONTAINER_STORAGE}" "\${var_unprivileged}" \
  || msg_error "Failed to create LXC container"
msg_ok "Created LXC container \${CTID}"

msg_info "Starting container"
start_lxc "\${CTID}" || msg_error "Failed to start container \${CTID}"

IP=\$(wait_for_container_ipv4 "\${CTID}")
[[ -z "\${IP}" ]] && msg_error "Container \${CTID} did not receive an IPv4 address after 60 s"
msg_ok "Container running — IPv4: \${IP}"

INSTALL_URL="https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/${APP}/install/${APP}-install.sh"
msg_info "Fetching install script"
copy_script_into_container "\${CTID}" "\${INSTALL_URL}" "/root/${APP}-install.sh" \
  || msg_error "Failed to fetch ${APP}-install.sh"
msg_ok "Fetched install script"

ensure_locale_profile "\${CTID}"

msg_info "Installing \${APP} inside container \${CTID}"
run_script_in_container "\${CTID}" "/root/${APP}-install.sh" \
  || msg_error "Installation failed — check /root/.install-${APP_LOG_SLUG}.log inside the container"
msg_ok "Installed \${APP}"

echo
printf '%b\\n' "\${CREATING}\${GN}\${APP} setup has been successfully initialized!\${CL}"
printf '%b\\n' "\${INFO}\${CL} Access it using the following URL:"
printf '%b\\n' "\${TAB}\${GATEWAY}\${BGN}http://\${IP}:${APP_PORT}\${CL}"
EOF

cat >"${APP_DIR}/install/${APP}-install.sh" <<EOF
#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/${UPSTREAM_REPO}

set -euo pipefail

APP="${APP_TITLE}"
APP_SLUG="${APP}"
APP_PORT="${APP_PORT}"
UPSTREAM_REPO="${UPSTREAM_REPO}"
INSTALL_LOG="\${INSTALL_LOG:-/root/.install-${APP_LOG_SLUG}.log}"
mkdir -p "\$(dirname "\${INSTALL_LOG}")"
log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$*" >> "\${INSTALL_LOG}"; }

YW=\$(printf '\\033[33m')
GN=\$(printf '\\033[1;92m')
RD=\$(printf '\\033[01;31m')
CL=\$(printf '\\033[m')
BFR='\\r\\033[K'
TAB='  '
CM="\${TAB}✔️\${TAB}"
CROSS="\${TAB}✖️\${TAB}"

msg_info()  { printf '%b\\n' "\${TAB}\${YW}◌\${CL} \${1}..."; }
msg_ok()    { printf "\${BFR}\${CM}\${GN}%s\${CL}\\n" "\${1}"; }
msg_error() { printf "\${BFR}\${CROSS}\${RD}%s\${CL}\\n" "\${1}"; exit 1; }

# Keep install scripts self-contained. If you need shared helper behavior here,
# inline the small function or explicitly fetch/copy the dependency into the container.

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

msg_info "Updating OS"
apt-get update -qq >> "\${INSTALL_LOG}" 2>&1 || msg_error "apt-get update failed"
apt-get upgrade -y -qq >> "\${INSTALL_LOG}" 2>&1 || msg_error "apt-get upgrade failed"
msg_ok "OS updated"

msg_info "Installing dependencies"
apt-get install -y -qq \
  curl \
  tar \
  ca-certificates >> "\${INSTALL_LOG}" 2>&1 || msg_error "Failed to install dependencies"
msg_ok "Installed dependencies"

mkdir -p /opt/${APP}/{config,data,logs}
msg_ok "Prepared application directories"

msg_info "Creating placeholder service"
cat <<SERVICE >/etc/systemd/system/${APP}.service
[Unit]
Description=${APP_TITLE} Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/${APP}
ExecStart=/bin/bash -lc 'echo "Replace ExecStart for ${APP_TITLE}" && sleep infinity'
SyslogIdentifier=${APP_TITLE}
User=root
Restart=always
RestartSec=5
NoNewPrivileges=true
Environment=HOME=/opt/${APP}
Environment=UMASK=022

[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable -q ${APP}.service
msg_ok "Service installed (not started)"

${UPDATE_HELPER_LINE}

msg_ok "${APP_TITLE} scaffold installation complete"
EOF

cat >"${BOOTSTRAP_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="obstruct-exit-emit"
REPO_NAME="proxmox-private-scripts"
APP_SLUG="${APP}"
APP_TITLE="${APP_TITLE}"
BRANCH="main"

BASE_RAW="https://raw.githubusercontent.com/\${REPO_OWNER}/\${REPO_NAME}/\${BRANCH}"
WORKDIR="\$(mktemp -d)"
trap 'rm -rf "\${WORKDIR}"' EXIT

fetch_file() {
  local relative_path="\$1"
  local destination="\$2"
  mkdir -p "\$(dirname "\${destination}")"
  curl -fsSL "\${BASE_RAW}/\${relative_path}" -o "\${destination}"
}

fetch_file "lib/output.sh" "\${WORKDIR}/lib/output.sh"
fetch_file "lib/common.sh" "\${WORKDIR}/lib/common.sh"
fetch_file "lib/lxc.sh" "\${WORKDIR}/lib/lxc.sh"
fetch_file "lib/github.sh" "\${WORKDIR}/lib/github.sh"
fetch_file "apps/\${APP_SLUG}/ct/\${APP_SLUG}.sh" "\${WORKDIR}/apps/\${APP_SLUG}/ct/\${APP_SLUG}.sh"

chmod +x "\${WORKDIR}/apps/\${APP_SLUG}/ct/\${APP_SLUG}.sh"
exec bash "\${WORKDIR}/apps/\${APP_SLUG}/ct/\${APP_SLUG}.sh"
EOF

chmod +x "${APP_DIR}/ct/${APP}.sh" "${APP_DIR}/install/${APP}-install.sh" "${BOOTSTRAP_PATH}"

echo "Created scaffold for ${APP} in ${APP_DIR} and ${BOOTSTRAP_PATH}"
