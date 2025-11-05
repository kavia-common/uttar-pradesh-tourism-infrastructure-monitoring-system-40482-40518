#!/usr/bin/env bash
set -euo pipefail
# Validation: Build, locate executable jar (jar or unzip), start app, probe health, capture logs, and stop cleanly
WS="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
cd "$WS"
# Source persisted envs when available (non-fatal)
. /etc/profile.d/spring_backend_env.sh >/dev/null 2>&1 || true
# Ensure required CLIs are present
for cmd in mvn java curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then echo "${cmd} not found; ensure env-001 completed" >&2; exit 2; fi
done
# Build package (skip tests to speed up validation)
mvn -q -DskipTests package
# Collect jars under target
mapfile -t JARS < <(find target -maxdepth 1 -type f -name "*.jar" -print0 | xargs -0 -n1 echo)
if [ ${#JARS[@]} -eq 0 ]; then echo "No jar found in target" >&2; exit 3; fi
# Determine inspection tool: prefer 'jar' then 'unzip'
JAR_CMD=jar
if ! command -v jar >/dev/null 2>&1; then
  if command -v unzip >/dev/null 2>&1; then
    JAR_CMD=unzip
  else
    echo "neither 'jar' nor 'unzip' available to inspect jars" >&2; exit 4
  fi
fi
EXECUTABLES=()
for j in "${JARS[@]}"; do
  if [ "$JAR_CMD" = "jar" ]; then
    if jar tf "$j" 2>/dev/null | grep -q "BOOT-INF"; then EXECUTABLES+=("$j"); fi
  else
    if unzip -l "$j" 2>/dev/null | grep -q "BOOT-INF"; then EXECUTABLES+=("$j"); fi
  fi
done
if [ ${#EXECUTABLES[@]} -eq 0 ]; then echo "No Spring Boot executable jar found" >&2; exit 5; fi
if [ ${#EXECUTABLES[@]} -gt 1 ]; then echo "Multiple executable jars found: ${EXECUTABLES[*]}" >&2; exit 6; fi
JAR_PATH="${EXECUTABLES[0]}"
LOG=/tmp/spring_backend.log
PIDFILE="$WS/spring_backend.pid"
SPRING_PROFILES_ACTIVE_VAL=${SPRING_PROFILES_ACTIVE:-dev}
SERVER_PORT_VAL=${SERVER_PORT:-8080}
DATABASE_URL_VAL=${DATABASE_URL:-jdbc:h2:file:${HOME}/.local/share/spring_backend_dev;DB_CLOSE_ON_EXIT=FALSE}
# Start the app with tuned JVM options
nohup java -Xmx512m -Dspring.profiles.active="$SPRING_PROFILES_ACTIVE_VAL" -Dserver.port="$SERVER_PORT_VAL" -Dspring.datasource.url="$DATABASE_URL_VAL" -jar "$JAR_PATH" >"$LOG" 2>&1 &
JAVA_PID=$!
echo "$JAVA_PID" > "$PIDFILE"
# Cleanup helper to stop the process cleanly
cleanup(){
  if [ -f "$PIDFILE" ]; then
    PID_TO_KILL=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "$PID_TO_KILL" ]; then
      kill "$PID_TO_KILL" 2>/dev/null || true
      sleep 2
      kill -9 "$PID_TO_KILL" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT
# Probe for /actuator/health or /health up to 30s
ENDPOINT=""
for i in $(seq 1 30); do
  sleep 1
  if curl -sS --max-time 2 "http://localhost:${SERVER_PORT_VAL}/actuator/health" >/dev/null 2>&1; then ENDPOINT="/actuator/health"; break; fi
  if curl -sS --max-time 2 "http://localhost:${SERVER_PORT_VAL}/health" >/dev/null 2>&1; then ENDPOINT="/health"; break; fi
done
if [ -z "$ENDPOINT" ]; then
  echo "App did not respond on /actuator/health or /health within timeout" >&2
  echo "--- last 200 lines of log ---"
  tail -n 200 "$LOG" || true
  exit 7
fi
# Print health response and recent logs
curl -sS "http://localhost:${SERVER_PORT_VAL}${ENDPOINT}" || true
echo "--- last 50 lines of log ---"
tail -n 50 "$LOG" || true
exit 0
