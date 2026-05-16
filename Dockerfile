# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Copy Maven wrapper and POM first for layer caching
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./

# Download dependencies (cached unless pom.xml changes)
RUN ./mvnw dependency:go-offline -q

# Copy source and build
COPY src/ src/
RUN ./mvnw package -DskipTests -q

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine AS runtime

ARG APP_UID=1000
ARG APP_GID=1000
ARG APP_USER=appuser
ARG APP_GROUP=appgroup
ARG ARTIFACT_FILE=app.jar

# Default JVM flags — can be overridden at runtime via JAVA_OPTS
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -Djava.security.egd=file:/dev/./urandom"

ENV ARTIFACT_FILE=${ARTIFACT_FILE}

WORKDIR /app

# Copy the fat JAR from builder
COPY --from=builder /app/target/*.jar ${ARTIFACT_FILE}

# Create app user/group
RUN addgroup -g ${APP_GID} ${APP_GROUP} && \
    adduser -r -u ${APP_UID} -G ${APP_GROUP} -h /app ${APP_USER} && \
    chown -R ${APP_USER}:${APP_GROUP} /app

USER ${APP_USER}

EXPOSE 8080

# CMD allows JAVA_OPTS to be overridden at runtime
CMD ["sh", "-c", "java $JAVA_OPTS -jar ${ARTIFACT_FILE}"]