# Conventions

## Host-side scripts

Host-side scripts should:

- source shared helpers from `lib/`
- define only app metadata and app-specific behavior where possible
- keep Proxmox/LXC boilerplate in shared helpers

## In-container installers

Install scripts should:

- use `set -euo pipefail`
- log to a predictable file when appropriate
- keep service definitions explicit and readable
- write an `/usr/bin/update` helper if in-place updating is supported

## Shared library guidelines

- `output.sh`: colors, icons, message functions
- `common.sh`: generic shell helpers
- `github.sh`: release/API/download helpers
- `lxc.sh`: Proxmox and container lifecycle helpers

## Readability

Prefer:

- short focused functions
- top-down file structure
- obvious naming over cleverness
- one app per folder with its own README
