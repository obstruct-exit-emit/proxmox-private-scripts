#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/obstruct-exit-emit/LibriNode

APP="LibriNode"
var_tags="${var_tags:-books;media;automation;arr}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../../.." && pwd)
# shellcheck source=lib/output.sh
source "${REPO_ROOT}/lib/output.sh"
# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/lxc.sh
source "${REPO_ROOT}/lib/lxc.sh"

update_script() {
  export LANG=C.UTF-8
  export LC_ALL=C.UTF-8
  unset LANGUAGE

  if [[ ! -d /opt/librinode-src ]]; then
    msg_error "No ${APP} Installation Found!"
  fi

  msg_info "Checking for updates"
  cd /opt/librinode-src || msg_error "Failed to cd to source directory"

  git fetch origin main
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
  git pull origin main || msg_error "git pull failed"
  msg_ok "Pulled $(git rev-parse --short HEAD)"

  msg_info "Building web UI"
  cd web || msg_error "web/ directory not found"
  npm ci --silent || msg_error "npm ci failed"
  npm run build --silent || msg_error "npm build failed"
  msg_ok "Built web UI"

  msg_info "Building LibriNode binary"
  cd /opt/librinode-src || exit 1
  CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=$(git describe --tags --always --dirty)" \
    -o /usr/local/bin/librinode ./cmd/librinode || msg_error "go build failed"
  chmod +x /usr/local/bin/librinode
  msg_ok "Built LibriNode binary"

  msg_info "Starting service"
  systemctl start librinode
  msg_ok "Started service"
  msg_ok "Updated successfully to $(git rev-parse --short HEAD)"
}

if ! command -v pveversion >/dev/null 2>&1; then
  update_script
  exit 0
fi

clear
printf '%b\n' "${BOLD}${GN}
  _     _ _          _ _   _           _
 | |   (_) |__ _ __(_) \\ | |___   __| | ___
 | |   | | '_ \\ '__| |  \\| / _ \\ / _\` |/ _ \\
 | |___| | |_) | |  | | |\\| (_) | (_| |  __/
 |_____|_|_.__/|_|  |_|_| \\_\\___/ \\__,_|\\___|
${CL}"
printf '%b\n' "  ${BOLD}${APP} LXC Installer${CL}"
echo

require_root
require_supported_arch

ARCH=$(dpkg --print-architecture)
msg_info "Checking storage"
find_storage_pools
msg_ok "Templates on ${TEMPLATE_STORAGE}, containers on ${CONTAINER_STORAGE}"

msg_info "Looking for ${var_os^} ${var_version} template (${ARCH})"
TEMPLATE=$(find_latest_template "$var_os" "$var_version" "$ARCH")
[[ -z "$TEMPLATE" ]] && msg_error "No ${var_os^} ${var_version} template found for ${ARCH}"
msg_ok "Found template: ${TEMPLATE}"

download_template_if_missing "$TEMPLATE_STORAGE" "$TEMPLATE"

CTID=$(next_ctid)
[[ -z "$CTID" ]] && msg_error "Could not determine next container ID"
HN="librinode"

msg_info "Creating LXC container ${CTID} (${HN})"
create_lxc "$CTID" "$TEMPLATE_STORAGE" "$TEMPLATE" "$HN" "community-script;${var_tags}" "$var_cpu" "$var_ram" "$var_disk" "$CONTAINER_STORAGE" "$var_unprivileged" \
  || msg_error "Failed to create LXC container"
msg_ok "Created LXC container ${CTID}"

msg_info "Starting container"
start_lxc "$CTID" || msg_error "Failed to start container ${CTID}"

IP=$(wait_for_container_ipv4 "$CTID")
[[ -z "$IP" ]] && msg_error "Container ${CTID} did not receive an IPv4 address after 60 s"
msg_ok "Container running — IPv4: ${IP}"

INSTALL_URL="https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/librinode/install/librinode-install.sh?nocache=$(date +%s)-${RANDOM}"
msg_info "Fetching install script"
copy_script_into_container "$CTID" "$INSTALL_URL" "/root/librinode-install.sh" \
  || msg_error "Failed to fetch librinode-install.sh"
msg_ok "Fetched install script"

ensure_locale_profile "$CTID"
enable_console_autologin "$CTID"

msg_info "Installing ${APP} inside container ${CTID}"
run_script_in_container "$CTID" "/root/librinode-install.sh" \
  || msg_error "Installation failed — check /root/.install-librinode.log inside the container"
msg_ok "Installed ${APP}"

echo
printf '%b\n' "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
printf '%b\n' "${INFO}${CL} Access it using the following URL:"
printf '%b\n' "${TAB}${GATEWAY}${BGN}http://${IP}:7845${CL}"
printf '%b\n' "${INFO}${CL} On first visit, create an admin account via the setup wizard."
printf '%b\n' "${TAB}To update to latest git version, run inside the container: ${BOLD}update${CL}"
