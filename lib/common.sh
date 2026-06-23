#!/usr/bin/env bash

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    msg_error "Please run this script as root."
  fi
}

require_supported_arch() {
  local arch
  arch=$(dpkg --print-architecture)
  if [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
    msg_error "Unsupported architecture: ${arch}"
  fi
}

ensure_locale_profile() {
  local ctid="$1"
  pct exec "$ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= bash -c 'printf "%s\n" "export LANG=C.UTF-8" "export LC_ALL=C.UTF-8" "unset LANGUAGE" >/etc/profile.d/99-locale.sh'
}

enable_console_autologin() {
  local ctid="$1"
  pct exec "$ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= bash -c 'mkdir -p /etc/systemd/system/console-getty.service.d && printf "%s\n" "[Service]" "ExecStart=" "ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud console 115200,38400,9600 \$TERM" >/etc/systemd/system/console-getty.service.d/override.conf && systemctl daemon-reload'
}
