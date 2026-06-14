#!/usr/bin/env bash
# Template for new app in-container installer

set -euo pipefail

APP="ExampleApp"
INSTALL_LOG="${INSTALL_LOG:-/root/.install-exampleapp.log}"
