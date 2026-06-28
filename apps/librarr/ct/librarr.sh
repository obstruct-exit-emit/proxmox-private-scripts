#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Copilot
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/JeremiahM37/librarr

APP="Librarr"
var_tags="${var_tags:-books;library;arr}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
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

  if [[ ! -f /opt/librarr/librarr ]]; then
    msg_error "No ${APP} Installation Found!"
  fi

  local arch asset_arch latest current version_no_v download_url binary tmp
  arch=$(dpkg --print-architecture)
  case "$arch" in
    amd64) asset_arch="amd64" ;;
    arm64) asset_arch="arm64" ;;
    *) msg_error "Unsupported architecture: ${arch}" ;;
  esac

  latest=$(get_latest_release_tag "JeremiahM37/librarr")
  [[ -z "$latest" ]] && msg_error "Could not determine latest release"
  current=$(cat /opt/librarr/VERSION 2>/dev/null || true)

  if [[ "$latest" == "$current" ]]; then
    msg_ok "Already up to date (${current})"
    exit 0
  fi

  version_no_v="${latest#v}"
  download_url="https://github.com/JeremiahM37/librarr/releases/download/${latest}/librarr_${version_no_v}_linux_${asset_arch}.tar.gz"

  msg_info "Stopping Service"
  systemctl stop librarr
  msg_ok "Stopped Service"

  msg_info "Downloading ${latest}"
  tmp=$(mktemp -d)
  if ! download_first_working_asset "${tmp}/librarr.tar.gz" "$download_url"; then
    rm -rf "$tmp"
    msg_error "Download failed for ${download_url}"
  fi
  msg_ok "Downloaded ${latest}"

  msg_info "Installing update"
  tar -xzf "${tmp}/librarr.tar.gz" -C "$tmp"
  binary=$(find "$tmp" -maxdepth 2 -type f -name "librarr" | head -1)
  if [[ -z "$binary" ]]; then
    rm -rf "$tmp"
    msg_error "librarr binary not found in archive"
  fi
  cp "$binary" /opt/librarr/librarr
  chmod +x /opt/librarr/librarr
  echo "$latest" >/opt/librarr/VERSION
  rm -rf "$tmp"
  msg_ok "Updated binary to ${latest}"

  msg_info "Starting Service"
  systemctl start librarr
  msg_ok "Started Service"
  msg_ok "Updated successfully!"
}

if ! command -v pveversion >/dev/null 2>&1; then
  update_script
  exit 0
fi

clear
printf '%b\n' "${BOLD}${GN}
  _     _ _
 | |   (_) |__  _ __ __ _ _ __ _ __
 | |   | | '_ \| '__/ _\` | '__| '__|
 | |___| | |_) | | | (_| | |  | |
 |_____|_|_.__/|_|  \__,_|_|  |_|
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
HN="librarr"

msg_info "Creating LXC container ${CTID} (${HN})"
create_lxc "$CTID" "$TEMPLATE_STORAGE" "$TEMPLATE" "$HN" "community-script;${var_tags}" "$var_cpu" "$var_ram" "$var_disk" "$CONTAINER_STORAGE" "$var_unprivileged" \
  || msg_error "Failed to create LXC container"
msg_ok "Created LXC container ${CTID}"

msg_info "Starting container"
start_lxc "$CTID" || msg_error "Failed to start container ${CTID}"

IP=$(wait_for_container_ipv4 "$CTID")
[[ -z "$IP" ]] && msg_error "Container ${CTID} did not receive an IPv4 address after 60 s"
msg_ok "Container running — IPv4: ${IP}"

INSTALL_URL="https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/librarr/install/librarr-install.sh?nocache=$(date +%s)-${RANDOM}"
msg_info "Fetching install script"
copy_script_into_container "$CTID" "$INSTALL_URL" "/root/librarr-install.sh" \
  || msg_error "Failed to fetch librarr-install.sh"
msg_ok "Fetched install script"

ensure_locale_profile "$CTID"
enable_console_autologin "$CTID"

msg_info "Installing ${APP} inside container ${CTID}"
run_script_in_container "$CTID" "/root/librarr-install.sh" \
  || msg_error "Installation failed — check /root/.install-librarr.log inside the container"
msg_ok "Installed ${APP}"

echo
printf '%b\n' "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
printf '%b\n' "${INFO}${CL} Access it using the following URL:"
printf '%b\n' "${TAB}${GATEWAY}${BGN}http://${IP}:5050${CL}"
printf '%b\n' "${INFO}${CL} Register the first admin account from the web UI, then edit"
printf '%b\n' "${TAB}/opt/librarr/librarr.env inside the container to wire up download"
printf '%b\n' "${TAB}clients, Prowlarr, and library targets, then: systemctl restart librarr"
