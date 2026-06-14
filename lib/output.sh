#!/usr/bin/env bash

YW=$(printf '\033[33m')
GN=$(printf '\033[1;92m')
BGN=$(printf '\033[4;92m')
RD=$(printf '\033[01;31m')
CL=$(printf '\033[m')
BOLD=$(printf '\033[1m')
BFR='\r\033[K'
TAB='  '
CM="${TAB}✔️${TAB}"
CROSS="${TAB}✖️${TAB}"
INFO="${TAB}💡${TAB}"
CREATING="${TAB}🚀${TAB}"
GATEWAY="${TAB}🌐${TAB}"

msg_info()  { printf '%b\n' "${TAB}${YW}◌${CL} ${1}..."; }
msg_ok()    { printf "${BFR}${CM}${GN}%s${CL}\n" "${1}"; }
msg_error() { printf "${BFR}${CROSS}${RD}%s${CL}\n" "${1}"; exit 1; }
