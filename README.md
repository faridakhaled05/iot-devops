# Smart IoT Monitoring System — DevOps Setup

## Project Overview

The Smart IoT Monitoring System is a full-stack IoT application designed
to collect, process, and analyze data from multiple sensors in real-time.

The system consists of three containerized components:

- **Backend** — Java Spring Boot (port 8080)
- **Frontend** — Angular + TypeScript served via Nginx (port 80)
- **Database** — MySQL 8.0 (port 3306)

All three components run as Docker containers connected through a shared
Docker network.

---

## Repository Structure

This repo is one of three sibling repositories:

```text
parent/
├── iot-devops/       ← this repo (Dockerfile.db, scripts, README)
├── iot-backend/      ← backend source code + Dockerfile
└── iot-frontend/     ← frontend source code + Dockerfile
```

---

## Prerequisites

- Docker 20.10.14 or higher — [Install Docker](https://docs.docker.com/get-docker/)
- A Docker Hub account — [hub.docker.com](https://hub.docker.com)

---

## Network Setup

All three containers communicate through a shared Docker network.
Create it once before running any container:

```bash
docker network create iot-net
```

---

## Quick Start (Pull from Docker Hub)

If you just want to run the project without building from source:

```bash
docker pull faridakhaled/iot-db:v1.0
docker pull faridakhaled/iot-backend:v1.0
docker pull faridakhaled/iot-frontend:v1.0
```

Then go directly to the **Run the Containers** section below.

---

## Build the Images (Only if Rebuilding from Source)

Only needed if the code has changed and you need to rebuild the images.
Run these commands from the parent folder:

```bash
docker build -t faridakhaled/iot-backend:v1.0 iot-backend/
docker build -t faridakhaled/iot-frontend:v1.0 iot-frontend/
docker build -f iot-devops/Dockerfile.db -t faridakhaled/iot-db:v1.0 iot-devops/
```

Or use the provided script from inside `iot-devops/`:

```bash
chmod +x build-and-push.sh
./build-and-push.sh
```

The script requires a `.env` file in `iot-devops/` with these variables:

```env
DOCKER_USERNAME=
DOCKER_PASSWORD=
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=
```

> ⚠️ Never commit the `.env` file. It is gitignored.

---

## Run the Containers

Run in this order — database first, then backend, then frontend:

```bash
docker run -d --name iot-mysql \
  --network iot-net \
  -e MYSQL_ROOT_PASSWORD='YOUR_SECURE_PASSWORD' \
  -p 3306:3306 \
  faridakhaled/iot-db:v1.0

docker run -d --name iot-api \
  --network iot-net \
  -p 8080:8080 \
  -e SPRING_DATASOURCE_URL='jdbc:mysql://iot-mysql:3306/iot_db' \
  -e SPRING_DATASOURCE_USERNAME=root \
  -e SPRING_DATASOURCE_PASSWORD='YOUR_SECURE_PASSWORD' \
  -e SPRING_PROFILES_ACTIVE=docker \
  -e JWT_SECRET='your-jwt-secret-min-32-characters' \
  faridakhaled/iot-backend:v1.0

docker run -d --name iot-web \
  --network iot-net \
  -p 80:80 \
  faridakhaled/iot-frontend:v1.0
```

> ⚠️ Replace `YOUR_SECURE_PASSWORD` with your actual MySQL password.
> `JWT_SECRET` must be at least 32 characters.

---

## Verification

Run the following to confirm all 3 containers are running:

```bash
docker ps
```

You should see these 3 containers with status **Up**:

- `iot-mysql` — port 3306
- `iot-api` — port 8080
- `iot-web` — port 80

To verify the frontend is accessible, open your browser at `http://localhost/`.

To verify the backend is responding:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected response: **HTTP 400** — confirms the server is up and input validation is working.

---

## Files in This Repo

| File | Purpose |
|------|---------|
| `README.md` | Full setup instructions |
| `Dockerfile.db` | MySQL 8.0 image |
| `build-and-push.sh` | Builds and pushes all 3 images to Docker Hub |
| `.env.example` | Credential template — copy to `.env` and fill in |
