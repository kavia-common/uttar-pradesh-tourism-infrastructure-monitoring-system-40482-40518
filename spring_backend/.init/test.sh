#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
cd "$WS"
if ! command -v mvn >/dev/null 2>&1; then echo "mvn not available" >&2; exit 2; fi
TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout 120s)
fi
# Run tests
if ! "${TIMEOUT_CMD[@]}" mvn -q test; then
  echo "Tests failed; printing surefire reports if present:" >&2
  if [ -d target/surefire-reports ]; then
    sed -n '1,200p' target/surefire-reports/* || true
  fi
  exit 3
fi
