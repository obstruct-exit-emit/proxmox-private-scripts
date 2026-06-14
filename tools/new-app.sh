#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <app-name>"
  exit 1
fi

APP="$1"
APP_DIR="apps/${APP}"
BOOTSTRAP_PATH="bootstrap/${APP}.sh"
APP_TITLE="$(printf '%s' "$APP" | sed -E 's/(^|-)([a-z])?/\U\2/g')"
APP_LOG_SLUG="${APP//[^a-zA-Z0-9_-]/-}"

mkdir -p "${APP_DIR}/ct" "${APP_DIR}/install" "bootstrap"

cat >"${APP_DIR}/README.md" <<EOF
# ${APP_TITLE}

App-specific notes go here.
EOF

cat >"${APP_DIR}/ct/${APP}.sh" <<EOF
#!/usr/bin/env bash
# Host-side LXC installer for ${APP_TITLE}

set -euo pipefail

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

APP="${APP_TITLE}"
msg_info "Scaffold created for \${APP}. Fill in app-specific logic in apps/${APP}/ct/${APP}.sh"
EOF

cat >"${APP_DIR}/install/${APP}-install.sh" <<EOF
#!/usr/bin/env bash
# In-container installer for ${APP_TITLE}

set -euo pipefail

APP="${APP_TITLE}"
INSTALL_LOG="\${INSTALL_LOG:-/root/.install-${APP_LOG_SLUG}.log}"
mkdir -p "\$(dirname "\${INSTALL_LOG}")"

SCRIPT_DIR=\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=\$(cd -- "\${SCRIPT_DIR}/../../.." && pwd)
# shellcheck source=lib/output.sh
source "\${REPO_ROOT}/lib/output.sh"
# shellcheck source=lib/github.sh
source "\${REPO_ROOT}/lib/github.sh"

msg_info "Scaffold created for \${APP}. Fill in app-specific logic in apps/${APP}/install/${APP}-install.sh"
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
