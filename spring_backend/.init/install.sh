#!/usr/bin/env bash
set -euo pipefail
# install maven non-interactively if missing
if ! command -v mvn >/dev/null 2>&1; then
  sudo apt-get update -q && sudo apt-get install -y -q maven
fi
# verify
command -v mvn >/dev/null && mvn -v || { echo "mvn missing" >&2; exit 1; }
