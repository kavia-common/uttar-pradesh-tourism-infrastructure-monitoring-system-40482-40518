#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
mkdir -p "$WS"
cmd_exists(){ command -v "$1" >/dev/null 2>&1; }
DETECTED_JAVA=""
if cmd_exists java; then
  JAVA_RAW=$(java -version 2>&1 || true)
  JAVA_MAJOR=$(printf "%s" "$JAVA_RAW" | grep -Eo '[0-9]+' | head -n1 || true)
  DETECTED_JAVA="$JAVA_RAW"
else
  JAVA_MAJOR=""
fi
DETECTED_MVN=""
if cmd_exists mvn; then
  MVN_RAW=$(mvn -v 2>/dev/null || true)
  MVN_VER=$(printf "%s" "$MVN_RAW" | awk '/Apache Maven/ {print $3}' || true)
  MVN_MAJOR=$(printf "%s" "$MVN_VER" | grep -Eo '^[0-9]+' || true)
  MVN_MINOR=$(printf "%s" "$MVN_VER" | awk -F. '{print $2}' || true)
  DETECTED_MVN="$MVN_RAW"
else
  MVN_MAJOR=""
fi
echo "detected java: ${DETECTED_JAVA:-<none>}"
echo "detected maven: ${DETECTED_MVN:-<none>}"
NEED_BUILD=${NEED_BUILD:-true}
PKGS=()
if [ -z "${JAVA_MAJOR:-}" ] || [ "${JAVA_MAJOR:-0}" -lt 17 ]; then
  sudo apt-get update -qq
  if [ "$NEED_BUILD" = "true" ]; then
    PKGS+=(openjdk-17-jdk)
  else
    PKGS+=(openjdk-17-jre-headless)
  fi
fi
if [ -z "${MVN_MAJOR:-}" ] || [ "${MVN_major:-0}" -lt 3 ]; then
  PKGS+=(maven)
elif [ -n "${MVN_MAJOR:-}" ] && [ "${MVN_MAJOR}" -eq 3 ] && [ -n "${MVN_MINOR:-}" ] && [ "${MVN_MINOR}" -lt 6 ]; then
  PKGS+=(maven)
fi
if ! cmd_exists unzip; then PKGS+=(unzip); fi
if [ ${#PKGS[@]} -gt 0 ]; then sudo apt-get install -y --no-install-recommends "${PKGS[@]}" >/dev/null; fi
if ! cmd_exists java; then echo "java not found after install" >&2; exit 2; fi
java -version 2>&1 | sed -n '1,3p'
if ! cmd_exists mvn; then echo "maven not found after install" >&2; exit 3; fi
mvn -v
PROFILE=/etc/profile.d/spring_backend_env.sh
if [ ! -f "$PROFILE" ]; then
  sudo tee "$PROFILE" > /dev/null <<'EOF'
# spring_backend runtime defaults (safe exports)
export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-dev}"
export SERVER_PORT="${SERVER_PORT:-8080}"
# DATABASE_URL single-quoted to avoid shell splitting; $HOME will be expanded when profile is sourced
export DATABASE_URL='${DATABASE_URL:-jdbc:h2:file:${HOME}/.local/share/spring_backend_dev;DB_CLOSE_ON_EXIT=FALSE}'
EOF
  sudo chmod 644 "$PROFILE"
fi
. /etc/profile.d/spring_backend_env.sh || true
