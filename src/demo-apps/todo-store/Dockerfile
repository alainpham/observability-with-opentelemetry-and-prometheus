# ---- Build stage: Maven 3.9.16 on Eclipse Temurin 25 (Java LTS) ----
FROM maven:3.9.16-eclipse-temurin-25-noble AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src/ src/
RUN mvn -B -q package -DskipTests

# ---- Runtime stage: Eclipse Temurin 25.0.4.1 JRE ----
FROM eclipse-temurin:25.0.4.1_1-jre-noble AS runtime
WORKDIR /app
COPY --from=build /src/target/todo-store.jar app.jar
EXPOSE 8080
USER 1000
ENTRYPOINT ["java", "-jar", "app.jar"]
