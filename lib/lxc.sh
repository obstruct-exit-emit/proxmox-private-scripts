#!/usr/bin/env bash

find_storage_pools() {
  TEMPLATE_STORAGE=$(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1{print $1; exit}') || true
  CONTAINER_STORAGE=$(pvesm status -content rootdir 2>/dev/null | awk 'NR>1{print $1; exit}') || true
  [[ -z "$TEMPLATE_STORAGE" ]] && msg_error "No storage with 'vztmpl' content type found"
  [[ -z "$CONTAINER_STORAGE" ]] && msg_error "No storage with 'rootdir' content type found"
}

find_latest_template() {
  local os="$1"
  local version="$2"
  local arch="$3"
  pveam available --section system 2>/dev/null \
    | awk -v os="$os" -v ver="$version" -v arch="$arch" \
        '$2 ~ os"-"ver"-" && $2 ~ "_"arch"." {print $2}' \
    | sort -V | tail -1 || true
}

download_template_if_missing() {
  local storage="$1"
  local template="$2"
  if ! pveam list "$storage" 2>/dev/null | grep -q "$template"; then
    msg_info "Downloading ${template}"
    pveam download "$storage" "$template" >/dev/null 2>&1 \
      || msg_error "Failed to download ${template}"
    msg_ok "Downloaded ${template}"
  fi
}

next_ctid() {
  pvesh get /cluster/nextid 2>/dev/null || true
}

create_lxc() {
  local ctid="$1"
  local template_storage="$2"
  local template="$3"
  local hostname="$4"
  local tags="$5"
  local cpu="$6"
  local ram="$7"
  local disk="$8"
  local container_storage="$9"
  local unprivileged="${10}"

  pct create "$ctid" "${template_storage}:vztmpl/${template}" \
    -hostname "$hostname" \
    -tags "$tags" \
    -cores "$cpu" \
    -memory "$ram" \
    -rootfs "${container_storage}:${disk}" \
    -net0 "name=eth0,bridge=vmbr0,ip=dhcp" \
    -features "nesting=1,keyctl=1" \
    -onboot 1 \
    -unprivileged "$unprivileged" \
    >/dev/null 2>&1
}

start_lxc() {
  local ctid="$1"
  pct start "$ctid" >/dev/null 2>&1
}

wait_for_container_ipv4() {
  local ctid="$1"
  local ip=""
  local i
  for i in $(seq 1 30); do
    sleep 2
    ip=$(pct exec "$ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= hostname -I 2>/dev/null | tr ' ' '\n' | grep -m1 -E '^[0-9]+(\.[0-9]+){3}$')
    [[ -n "$ip" ]] && break
  done
  printf '%s' "$ip"
}

copy_script_into_container() {
  local ctid="$1"
  local source_url="$2"
  local target_path="$3"
  curl -fsSL "$source_url" \
    | pct exec "$ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= tee "$target_path" >/dev/null 2>&1
  pct exec "$ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= chmod +x "$target_path"
}

run_script_in_container() {
  local ctid="$1"
  local script_path="$2"
  pct exec "$ctid" -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE= bash "$script_path"
}
