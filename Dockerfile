FROM openjdk:17-slim

WORKDIR /app

COPY target/github-actions-demo-*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]