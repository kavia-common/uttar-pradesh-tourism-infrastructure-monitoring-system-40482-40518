#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
cd "$WORKSPACE"
PORT=${PORT:-8080}
export SPRING_PROFILES_ACTIVE=dev
export SERVER_PORT=${PORT}
# disable common telemetry/production metrics in dev
export MANAGEMENT_METRICS_EXPORT_SIMPLE_ENABLED=false
export MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED=false
TERM=${TERM:-dumb}
LOG=/tmp/spring_dev.log
# Start mvn in its own session so we can kill the whole group reliably
setsid bash -lc "mvn -Dspring-boot.run.profiles=dev spring-boot:run" >"$LOG" 2>&1 &
APP_PID=$!
# Resolve PGID for group termination
PGID=$(ps -o pgid= "$APP_PID" | tr -d ' ' || true)
trap 'if [ -n "${PGID}" ]; then kill -TERM -${PGID} 2>/dev/null || true; fi' EXIT INT TERM
# Wait for readiness (30 tries x 2s = ~60s)
TRIES=0
until curl -sSf --connect-timeout 2 "http://127.0.0.1:${PORT}/actuator/health" >/dev/null 2>&1 || [ $TRIES -ge 30 ]; do
  sleep 2
  TRIES=$((TRIES+1))
done
if [ $TRIES -ge 30 ]; then
  echo "ERROR: dev server did not become ready; last 200 lines:" >&2
  tail -n 200 "$LOG" >&2 || true
  exit 20
fi
# Print health output for caller
curl -s "http://127.0.0.1:${PORT}/actuator/health"
# Keep script running so trap will clean up when caller stops it; if caller wants only readiness check they can run and exit
wait
