#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/uttar-pradesh-tourism-infrastructure-monitoring-system-40482-40518/spring_backend"
mkdir -p "$WS" && cd "$WS"
# Minimal pom.xml
cat > pom.xml <<'POM'
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>org.example</groupId>
  <artifactId>spring-backend</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.6</version>
    <relativePath/>
  </parent>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
POM
mkdir -p src/main/java/org/example src/main/resources src/test/java/org/example
cat > src/main/java/org/example/Application.java <<'JAVA'
package org.example;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
@SpringBootApplication
public class Application { public static void main(String[] args){ SpringApplication.run(Application.class,args);} }
JAVA
cat > src/main/java/org/example/HealthController.java <<'JAVA'
package org.example;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
@RestController
public class HealthController { @GetMapping("/health") public Map<String,String> health(){ return Map.of("status","UP"); } }
JAVA
# application-dev.properties: uses ${user.home} (Spring runtime) and server.port fallback
cat > src/main/resources/application-dev.properties <<'PROP'
spring.datasource.url=${DATABASE_URL:jdbc:h2:file:${user.home}/.local/share/spring_backend_dev;DB_CLOSE_ON_EXIT=FALSE}
spring.datasource.driverClassName=org.h2.Driver
spring.h2.console.enabled=true
management.endpoints.web.exposure.include=health,info
management.endpoint.health.show-details=always
logging.level.root=INFO
server.port=${SERVER_PORT:8080}
PROP
cat > src/test/java/org/example/ApplicationTest.java <<'TEST'
package org.example;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;
class ApplicationTest { @Test void sanity(){ assertTrue(true); } }
TEST
# Uploads dir: deterministic ownership strategy
mkdir -p "$WS/uploads"
if [ "$(id -u)" -ne 0 ]; then
  # running as non-root inside container: ensure writable
  chmod 0777 "$WS/uploads" || true
else
  # if RUN_AS_USER provided, chown; otherwise leave permissive for dev
  if [ -n "${RUN_AS_USER:-}" ] && id -u "${RUN_AS_USER}" >/dev/null 2>&1; then
    sudo chown -R "${RUN_AS_USER}:${RUN_AS_USER}" "$WS/uploads" || true
  else
    sudo chmod 0777 "$WS/uploads" || true
  fi
fi
