#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <app-name>"
  exit 1
fi

APP="$1"
APP_DIR="apps/${APP}"
BOOTSTRAP_PATH="bootstrap/${APP}.sh"

mkdir -p "${APP_DIR}/ct" "${APP_DIR}/install" "bootstrap"

cat >"${APP_DIR}/README.md" <<EOF
# ${APP}

App-specific notes go here.
EOF

cp templates/ct-template.sh "${APP_DIR}/ct/${APP}.sh"
cp templates/app-install-template.sh "${APP_DIR}/install/${APP}-install.sh"

cat >"${BOOTSTRAP_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="obstruct-exit-emit"
REPO_NAME="proxmox-private-scripts"
APP_SLUG="${APP}"
APP_TITLE="${APP}"
BRANCH="main"

BASE_RAW="https://raw.githubusercontent.com/4{REPO_OWNER}/4{REPO_NAME}/4{BRANCH}"
WORKDIR="4(mktemp -d)"
trap 'rm -rf "4WORKDIR"' EXIT

fetch_file() {
  local relative_path="41"
  local destination="42"
  mkdir -p "4(dirname "4destination")"
  curl -fsSL "4{BASE_RAW}/4{relative_path}" -o "4destination"
}

fetch_file "lib/output.sh" "4{WORKDIR}/lib/output.sh"
fetch_file "lib/common.sh" "4{WORKDIR}/lib/common.sh"
fetch_file "lib/lxc.sh" "4{WORKDIR}/lib/lxc.sh"
fetch_file "lib/github.sh" "4{WORKDIR}/lib/github.sh"
fetch_file "apps/4{APP_SLUG}/ct/4{APP_SLUG}.sh" "4{WORKDIR}/apps/4{APP_SLUG}/ct/4{APP_SLUG}.sh"

chmod +x "4{WORKDIR}/apps/4{APP_SLUG}/ct/4{APP_SLUG}.sh"
exec bash "4{WORKDIR}/apps/4{APP_SLUG}/ct/4{APP_SLUG}.sh"
EOF

chmod +x "${APP_DIR}/ct/${APP}.sh" "${APP_DIR}/install/${APP}-install.sh" "${BOOTSTRAP_PATH}"

echo "Created scaffold for ${APP} in ${APP_DIR} and ${BOOTSTRAP_PATH}"
