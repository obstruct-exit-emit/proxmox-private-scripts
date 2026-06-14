#!/usr/bin/env bash

get_latest_release_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep '"tag_name"' | head -1 | grep -Po '"tag_name":\s*"\K[^"]+' || true
}

download_first_working_asset() {
  local destination="$1"
  shift
  local url
  for url in "$@"; do
    if curl -fsSLI --location "$url" >/dev/null 2>&1; then
      curl -fsSL --location "$url" -o "$destination"
      return 0
    fi
  done
  return 1
}
