#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/pia-foss/manual-connections

APP="JDownloader2 + PIA"
APP_SLUG="jd2-pia"
APP_INSTALL_SCRIPT="jd2-pia-install.sh"
var_tags="${var_tags:-vpn;downloader}"
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
  if [[ ! -d /opt/pia-manual-connections ]]; then
    msg_error "No ${APP} Installation Found!"
  fi
  bash /usr/local/bin/jd2-pia-update
  exit 0
}

if ! command -v pveversion >/dev/null 2>&1; then
  update_script
  exit 0
fi

clear
printf '%b\n' "${BOLD}${GN}\n  ${APP} LXC Installer${CL}"
echo

require_root
require_supported_arch

ARCH=$(dpkg --print-architecture)
msg_info "Checking storage"
find_storage_pools
msg_ok "Templates on ${TEMPLATE_STORAGE}, containers on ${CONTAINER_STORAGE}"

msg_info "Looking for ${var_os^} ${var_version} template (${ARCH})"
TEMPLATE=$(find_latest_template "${var_os}" "${var_version}" "${ARCH}")
[[ -z "${TEMPLATE}" ]] && msg_error "No ${var_os^} ${var_version} template found for ${ARCH}"
msg_ok "Found template: ${TEMPLATE}"

download_template_if_missing "${TEMPLATE_STORAGE}" "${TEMPLATE}"

CTID=$(next_ctid)
[[ -z "${CTID}" ]] && msg_error "Could not determine next container ID"
HN="jd2-pia"

msg_info "Creating LXC container ${CTID} (${HN})"
create_lxc "${CTID}" "${TEMPLATE_STORAGE}" "${TEMPLATE}" "${HN}" "community-script;${var_tags}" "${var_cpu}" "${var_ram}" "${var_disk}" "${CONTAINER_STORAGE}" "${var_unprivileged}"   || msg_error "Failed to create LXC container"
msg_ok "Created LXC container ${CTID}"

msg_info "Starting container"
start_lxc "${CTID}" || msg_error "Failed to start container ${CTID}"

IP=$(wait_for_container_ipv4 "${CTID}")
[[ -z "${IP}" ]] && msg_error "Container ${CTID} did not receive an IPv4 address after 60 s"
msg_ok "Container running — IPv4: ${IP}"

INSTALL_URL="https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/jd2-pia/install/jd2-pia-install.sh"
msg_info "Fetching install script"
copy_script_into_container "${CTID}" "${INSTALL_URL}" "/root/jd2-pia-install.sh"   || msg_error "Failed to fetch jd2-pia-install.sh"
msg_ok "Fetched install script"

ensure_locale_profile "${CTID}"
enable_console_autologin "${CTID}"

msg_info "Installing ${APP} inside container ${CTID}"
run_script_in_container "${CTID}" "/root/jd2-pia-install.sh"   || msg_error "Installation failed — check /root/.install-jd2-pia.log inside the container"
msg_ok "Installed ${APP}"

echo
printf '%b\n' "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
printf '%b\n' "${INFO}${CL} JDownloader2 is running but NOT yet routed through PIA. Finish setup:"
printf '%b\n' "${TAB}1) pct enter ${CTID}"
printf '%b\n' "${TAB}2) pia-setup.sh   ${TAB}# one-time PIA login + first VPN connect + kill switch"
printf '%b\n' "${TAB}3) Pair this JDownloader2 instance at https://my.jdownloader.org"
