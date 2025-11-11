#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
cd "$WORKSPACE"
PORT=${PORT:-8080}
LOG=/tmp/spring_dev.log

# warn about production APM deps
if [ -f pom.xml ]; then
  if grep -E "(datadog|newrelic|sentry|elastic-apm|opentelemetry)" pom.xml >/dev/null 2>&1; then
    echo "WARNING: pom.xml contains production APM/EDR dependencies; ensure dev profile disables them" >&2
  fi
fi

# Build package (skip tests for speed)
if ! command -v mvn >/dev/null 2>&1; then
  echo "ERROR: mvn not found on PATH" >&2; exit 20
fi
mvn -q -DskipTests package

# Discover jar in target reliably
JAR=$(find target -maxdepth 1 -type f -name "*.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | head -n1 || true)
if [ -z "$JAR" ]; then
  echo "ERROR: built jar not found in target" >&2; exit 30
fi

JAVA_BIN=$(command -v java || true)
if [ -z "$JAVA_BIN" ]; then
  echo "ERROR: java not found" >&2; exit 31
fi

# Ensure previous log cleared
: >"$LOG" || true

# Start the jar in its own session so we can kill the PGID
setsid "$JAVA_BIN" -Dspring.profiles.active=dev -Dmanagement.metrics.export.simple.enabled=false -Dmanagement.metrics.export.prometheus.enabled=false -jar "$JAR" --server.port=${PORT} >"$LOG" 2>&1 &
APP_PID=$!
PGID=$(ps -o pgid= "$APP_PID" | tr -d ' ' || true)

# Ensure PGID variable exists for trap
trap 'if [ -n "${PGID:-}" ]; then kill -TERM -${PGID} 2>/dev/null || true; fi; wait "${APP_PID:-}" 2>/dev/null || true' EXIT INT TERM

# Readiness wait: try actuator/health then /
TRIES=0
until curl -sSf --connect-timeout 2 "http://127.0.0.1:${PORT}/actuator/health" >/dev/null 2>&1 || curl -sSf --connect-timeout 2 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1 || [ $TRIES -ge 30 ]; do
  sleep 2
  TRIES=$((TRIES+1))
done

if [ $TRIES -ge 30 ]; then
  echo "ERROR: app did not become ready within timeout; last 200 lines of log:" >&2
  tail -n 200 "${LOG}" >&2 || true
  if [ -n "${PGID:-}" ]; then kill -TERM -${PGID} 2>/dev/null || true; fi
  exit 32
fi

# Evidence: print actuator/health if available, otherwise root
curl -s "http://127.0.0.1:${PORT}/actuator/health" || curl -s "http://127.0.0.1:${PORT}/"

# Clean stop
if [ -n "${PGID:-}" ]; then
  kill -TERM -${PGID} 2>/dev/null || true
fi
wait "$APP_PID" 2>/dev/null || true

exit 0
