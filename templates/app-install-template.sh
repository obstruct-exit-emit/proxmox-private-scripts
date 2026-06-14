#!/usr/bin/env bash
# Template for new app in-container installer

set -euo pipefail

APP="ExampleApp"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-exampleapp.log}"
mkdir -p "$(dirname "$INSTALL_LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$INSTALL_LOG"; }

YW=$(printf '\033[33m')
GN=$(printf '\033[1;92m')
RD=$(printf '\033[01;31m')
CL=$(printf '\033[m')
BFR='\r\033[K'
TAB='  '
CM="${TAB}✔️${TAB}"
CROSS="${TAB}✖️${TAB}"

msg_info()  { printf '%b\n' "${TAB}${YW}◌${CL} ${1}..."; }
msg_ok()    { printf "${BFR}${CM}${GN}%s${CL}\n" "${1}"; }
msg_error() { printf "${BFR}${CROSS}${RD}%s${CL}\n" "${1}"; exit 1; }

# Keep install templates self-contained. If you need shared helper behavior here,
# inline the small function or explicitly fetch/copy the dependency into the container.

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
