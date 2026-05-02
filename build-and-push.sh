#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example to .env and set DOCKER_USERNAME, DOCKER_PASSWORD, IMAGE_TAG."
  exit 1
fi

# shellcheck source=/dev/null
source .env

: "${DOCKER_USERNAME:?Set DOCKER_USERNAME in .env}"
: "${DOCKER_PASSWORD:?Set DOCKER_PASSWORD in .env}"
: "${IMAGE_TAG:?Set IMAGE_TAG in .env}"

BACKEND_DIR="../iot-backend"
FRONTEND_DIR="../iot-frontend"
if [[ ! -d "$BACKEND_DIR" ]] || [[ ! -d "$FRONTEND_DIR" ]]; then
  echo "Expected $BACKEND_DIR and $FRONTEND_DIR to exist (clone iot-backend and iot-frontend next to this repo)."
  exit 1
fi

docker login --username "$DOCKER_USERNAME" --password "$DOCKER_PASSWORD"

docker build -f "$BACKEND_DIR/Dockerfile" -t "$DOCKER_USERNAME/iot-backend:$IMAGE_TAG" "$BACKEND_DIR"
docker push "$DOCKER_USERNAME/iot-backend:$IMAGE_TAG"

docker build -f "$FRONTEND_DIR/Dockerfile" -t "$DOCKER_USERNAME/iot-frontend:$IMAGE_TAG" "$FRONTEND_DIR"
docker push "$DOCKER_USERNAME/iot-frontend:$IMAGE_TAG"

docker build -f ./Dockerfile.db -t "$DOCKER_USERNAME/iot-db:$IMAGE_TAG" .
docker push "$DOCKER_USERNAME/iot-db:$IMAGE_TAG"

echo "Done. Pushed $DOCKER_USERNAME/iot-{backend,frontend,db}:$IMAGE_TAG"
