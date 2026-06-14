#!/usr/bin/env bash
set -euo pipefail

find lib apps tools -type f \( -name '*.sh' -o -path '*/ct/*' -o -path '*/install/*' \) -print | while read -r file; do
  bash -n "$file"
  echo "OK: $file"
done
