FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build

COPY ./pom.xml ./
COPY ./src ./src

RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre

WORKDIR /app

# install curl for healthcheck
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/target/*.jar app.jar
EXPOSE 8080

CMD [ "java", "-jar", "app.jar" ]