#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
cd "$WORKSPACE"
# derive package from pom.xml groupId if present
GROUP_ID=$(xmllint --xpath 'string(/project/groupId)' pom.xml 2>/dev/null || true)
if [ -z "${GROUP_ID}" ]; then GROUP_ID=$(xmllint --xpath 'string(/project/parent/groupId)' pom.xml 2>/dev/null || true || true); fi
PACKAGE=${GROUP_ID:-dev.container}
PKG_DIR=src/test/java/${PACKAGE//./\/}
mkdir -p "$PKG_DIR"
TEST_FILE="$PKG_DIR/SmokeTest.java"
if [ ! -f "$TEST_FILE" ]; then
  cat > "$TEST_FILE" <<JAVA
package ${PACKAGE};
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;
class SmokeTest {
  @Test void basic() { assertTrue(true); }
}
JAVA
fi
# run the single test to validate test harness
mvn -q -Dtest=${PACKAGE}.SmokeTest test
