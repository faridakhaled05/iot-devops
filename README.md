# Smart IoT Monitoring System — iot-devops

This repository holds **operations-only** assets: how to build and publish the database image, build/push all service images, and run the stack with the Docker CLI.

**Expected layout** (sibling folders — same parent directory):

```text
parent/
  iot-devops/      ← this repo
  iot-backend/     ← application source + Dockerfile
  iot-frontend/    ← application source + Dockerfile
```

---

## Prerequisites

- Docker 20.10+ — [Install Docker](https://docs.docker.com/get-docker/)
- A container registry account (e.g. [Docker Hub](https://hub.docker.com)) if you use `build-and-push.sh`
- Cloned **iot-backend** and **iot-frontend** next to this repo (for local image builds)

---

## Network

Create the shared network once:

```bash
docker network create iot-net
```

---

## Build images (local tags)

From the **parent** folder (the one that contains `iot-devops`, `iot-backend`, and `iot-frontend`):

```bash
export NS=your-dockerhub-username
export TAG=v1.0

docker build -t "$NS/iot-backend:$TAG" iot-backend/
docker build -t "$NS/iot-frontend:$TAG" iot-frontend/
docker build -f iot-devops/Dockerfile.db -t "$NS/iot-db:$TAG" iot-devops/
```

Or from **inside** `iot-devops/` (only if `../iot-backend` and `../iot-frontend` exist):

```bash
export NS=your-dockerhub-username
export TAG=v1.0

docker build -t "$NS/iot-backend:$TAG" ../iot-backend/
docker build -t "$NS/iot-frontend:$TAG" ../iot-frontend/
docker build -f Dockerfile.db -t "$NS/iot-db:$TAG" .
```

---

## Build and push to Docker Hub

1. Copy the environment template and edit it:

   ```bash
   cd iot-devops
   cp .env.example .env
   ```

2. Set `DOCKER_USERNAME`, `DOCKER_PASSWORD` (use an [access token](https://docs.docker.com/docker-hub/access-tokens/) for Hub), and `IMAGE_TAG` in `.env`.

3. Run:

   ```bash
   chmod +x build-and-push.sh
   ./build-and-push.sh
   ```

The script builds `iot-backend` and `iot-frontend` from **sibling** directories and builds `iot-db` from `Dockerfile.db` in this repo, then pushes all three images.

---

## Run containers (Docker CLI)

Use the same image names you built (replace `your-dockerhub-username` and `v1.0` with your values). **Start MySQL first** and wait until it accepts connections before starting the API.

```bash
# Optional: wait for MySQL after the first run
# until docker exec iot-mysql mysqladmin ping -h localhost --silent; do sleep 2; done

docker run -d --name iot-mysql \
  --network iot-net \
  -e MYSQL_ROOT_PASSWORD='YOUR_SECURE_PASSWORD' \
  -p 3306:3306 \
  your-dockerhub-username/iot-db:v1.0

docker run -d --name iot-api \
  --network iot-net \
  -p 8080:8080 \
  -e SPRING_DATASOURCE_URL='jdbc:mysql://iot-mysql:3306/iot_db' \
  -e SPRING_DATASOURCE_USERNAME=root \
  -e SPRING_DATASOURCE_PASSWORD='YOUR_SECURE_PASSWORD' \
  -e SPRING_PROFILES_ACTIVE=docker \
  -e JWT_SECRET='your-jwt-secret-at-least-32-characters-long' \
  your-dockerhub-username/iot-backend:v1.0

docker run -d --name iot-web \
  --network iot-net \
  -p 80:80 \
  your-dockerhub-username/iot-frontend:v1.0
```

Replace `YOUR_SECURE_PASSWORD` everywhere you use the MySQL root password. `JWT_SECRET` must be at least 32 characters.

> `SPRING_PROFILES_ACTIVE=docker` is optional if the backend image already sets it in its Dockerfile.

---

## Verification

```bash
docker ps
```

You should see `iot-mysql`, `iot-api`, and `iot-web` **Up**.

- **Frontend:** [http://localhost/](http://localhost/)
- **Backend** (no Actuator in this project): empty login body should return **400**:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Database image

- **`Dockerfile.db`** — MySQL 8.0, database name `iot_db`. Root password is **not** in the image; pass `MYSQL_ROOT_PASSWORD` at `docker run` (see above).

---

## Files in this repo

| File | Purpose |
|------|--------|
| `README.md` | Network, build, run, verify |
| `Dockerfile.db` | MySQL image build |
| `build-and-push.sh` | Login, build sibling apps, build DB, push all three |
| `.env.example` | Template for registry credentials and image tag (copy to `.env`) |

Do **not** commit `.env` (it is gitignored).
