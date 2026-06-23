#!/usr/bin/env bash
set -euo pipefail

HAS_SHELLCHECK=0
if command -v shellcheck >/dev/null 2>&1; then
  HAS_SHELLCHECK=1
else
  echo "shellcheck not found on PATH — skipping lint, running syntax checks only" >&2
fi

find lib apps tools -type f \( -name '*.sh' -o -path '*/ct/*' -o -path '*/install/*' \) -print | while read -r file; do
  bash -n "$file"
  if [[ "$HAS_SHELLCHECK" -eq 1 ]]; then
    shellcheck -x "$file"
  fi
  echo "OK: $file"
done
