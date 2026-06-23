#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/sirrobot01/decypharr

APP="Decypharr"
var_tags="${var_tags:-torrent;debrid;usenet}"
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
# shellcheck source=lib/github.sh
source "${REPO_ROOT}/lib/github.sh"

update_script() {
  export LANG=C.UTF-8
  export LC_ALL=C.UTF-8
  unset LANGUAGE

  if [[ ! -f /opt/decypharr/decypharr ]]; then
    msg_error "No ${APP} Installation Found!"
  fi

  local arch asset latest current download_url binary
  arch=$(dpkg --print-architecture)
  case "$arch" in
    amd64) asset="decypharr_linux_amd64.tar.gz" ;;
    arm64) asset="decypharr_linux_arm64.tar.gz" ;;
    *) msg_error "Unsupported architecture: ${arch}" ;;
  esac

  latest=$(get_latest_release_tag "sirrobot01/decypharr")
  current=$(/opt/decypharr/decypharr --version 2>/dev/null | awk '{print $NF}' || true)

  if [[ -n "$latest" && "$latest" == "$current" ]]; then
    msg_ok "Already up to date (${current})"
    exit 0
  fi

  download_url="https://github.com/sirrobot01/decypharr/releases/latest/download/${asset}"
  msg_info "Stopping Service"
  systemctl stop decypharr
  msg_ok "Stopped Service"

  msg_info "Downloading ${asset}"
  curl -fsSL --location "$download_url" -o /tmp/decypharr.tar.gz \
    || msg_error "Download failed"
  tar -xzf /tmp/decypharr.tar.gz -C /tmp
  binary=$(find /tmp -maxdepth 2 -type f -name "decypharr" | head -1)
  [[ -z "$binary" ]] && msg_error "Binary not found in archive"
  cp "$binary" /opt/decypharr/decypharr
  chmod +x /opt/decypharr/decypharr
  rm -f /tmp/decypharr.tar.gz
  msg_ok "Updated binary"

  msg_info "Starting Service"
  systemctl start decypharr
  msg_ok "Started Service"
  msg_ok "Updated successfully!"
}

if ! command -v pveversion >/dev/null 2>&1; then
  update_script
  exit 0
fi

clear
printf '%b\n' "${BOLD}${GN}
   ____                           _                    
  |  _ \  ___  ___ _   _ _ __ | |__   __ _ _ __ _ __ 
  | | | |/ _ \/ __| | | | '_ \| '_ \ / _\\  | '__| '__|
  | |_| |  __/ (__| |_| | |_) | | | | (_| | |  | |   
  |____/ \___|\___|\__, | .__/|_| |_|\__,_|_|  |_|   
                   |___/|_|                            
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
HN="decypharr"

msg_info "Creating LXC container ${CTID} (${HN})"
create_lxc "$CTID" "$TEMPLATE_STORAGE" "$TEMPLATE" "$HN" "community-script;${var_tags}" "$var_cpu" "$var_ram" "$var_disk" "$CONTAINER_STORAGE" "$var_unprivileged" \
  || msg_error "Failed to create LXC container"
msg_ok "Created LXC container ${CTID}"

msg_info "Starting container"
start_lxc "$CTID" || msg_error "Failed to start container ${CTID}"

IP=$(wait_for_container_ipv4 "$CTID")
[[ -z "$IP" ]] && msg_error "Container ${CTID} did not receive an IPv4 address after 60 s"
msg_ok "Container running — IPv4: ${IP}"

INSTALL_URL="https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/decypharr/install/decypharr-install.sh?nocache=$(date +%s)-${RANDOM}"
msg_info "Fetching install script"
copy_script_into_container "$CTID" "$INSTALL_URL" "/root/decypharr-install.sh" \
  || msg_error "Failed to fetch decypharr-install.sh"
msg_ok "Fetched install script"

ensure_locale_profile "$CTID"
enable_console_autologin "$CTID"

msg_info "Installing ${APP} inside container ${CTID}"
run_script_in_container "$CTID" "/root/decypharr-install.sh" \
  || msg_error "Installation failed — check /root/.install-decypharr.log inside the container"
msg_ok "Installed ${APP}"

echo
printf '%b\n' "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
printf '%b\n' "${INFO}${CL} Access it using the following URL:"
printf '%b\n' "${TAB}${GATEWAY}${BGN}http://${IP}:8282${CL}"
