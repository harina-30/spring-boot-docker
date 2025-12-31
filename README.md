![CI](https://github.com/harina-30/spring-boot-docker/actions/workflows/pipeline.yml/badge.svg)

Just a sample hello world application using Java/Spring Boot

**Pull the built image:**

```bash
# Pull latest from GHCR (if image is public or you are authenticated)
# docker pull ghcr.io/harina-30/spring-boot-app:latest
```


## Docker Compose (recommended)

Commands (run in `coursera-spring-hello-world1`):

- Start (build and run):
  ```powershell
  docker compose up --build
  ```

- Stop and remove:
  ```powershell
  docker compose down
  ```

Notes:
- The app is exposed on **host port 8080** and container port **8080**: http://localhost:8080/greeting
- If Docker Compose reports "no configuration file provided", make sure you are in this folder or point to the file with `-f` (quote paths with spaces).
- If you see daemon/pipe errors, ensure Docker Desktop is running and set to use Linux containers. Check: `docker info`.

## Run without Docker

- Build locally: `./mvnw.cmd clean package`
- Run jar: `java -jar target\coursera-0.0.1-SNAPSHOT.jar --server.port=8080`
