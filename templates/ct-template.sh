#!/usr/bin/env bash
# Template for new app host-side LXC installer

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../../.." && pwd)
# shellcheck source=lib/output.sh
source "${REPO_ROOT}/lib/output.sh"
# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/lxc.sh
source "${REPO_ROOT}/lib/lxc.sh"

APP="ExampleApp"
