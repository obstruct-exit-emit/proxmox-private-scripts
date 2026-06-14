#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <app-name>"
  exit 1
fi

APP="$1"
APP_DIR="apps/${APP}"

mkdir -p "${APP_DIR}/ct" "${APP_DIR}/install"

cat >"${APP_DIR}/README.md" <<EOF
# ${APP}

App-specific notes go here.
EOF

cp templates/ct-template.sh "${APP_DIR}/ct/${APP}.sh"
cp templates/app-install-template.sh "${APP_DIR}/install/${APP}-install.sh"

chmod +x "${APP_DIR}/ct/${APP}.sh" "${APP_DIR}/install/${APP}-install.sh"

echo "Created scaffold for ${APP} in ${APP_DIR}"
