#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="obstruct-exit-emit"
REPO_NAME="proxmox-private-scripts"
APP_SLUG="shelfmark"
APP_TITLE="Shelfmark"
BRANCH="main"

BASE_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

fetch_file() {
  local relative_path="$1"
  local destination="$2"
  mkdir -p "$(dirname "${destination}")"
  curl -fsSL "${BASE_RAW}/${relative_path}?nocache=$(date +%s)-${RANDOM}" -o "${destination}"
}

fetch_file "lib/output.sh" "${WORKDIR}/lib/output.sh"
fetch_file "lib/common.sh" "${WORKDIR}/lib/common.sh"
fetch_file "lib/lxc.sh" "${WORKDIR}/lib/lxc.sh"
fetch_file "lib/github.sh" "${WORKDIR}/lib/github.sh"
fetch_file "apps/${APP_SLUG}/ct/${APP_SLUG}.sh" "${WORKDIR}/apps/${APP_SLUG}/ct/${APP_SLUG}.sh"

chmod +x "${WORKDIR}/apps/${APP_SLUG}/ct/${APP_SLUG}.sh"
exec bash "${WORKDIR}/apps/${APP_SLUG}/ct/${APP_SLUG}.sh"
