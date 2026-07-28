# Sensorix — DevOps Setup 

## Project Overview

Sensorix is a full-stack IoT monitoring system that collects, processes, and visualizes
real-time sensor data for traffic, air pollution, and street lighting.

The system consists of three containerized components:

- **Backend** — Java Spring Boot (port 8080)
- **Frontend** — Angular 21 served via Nginx (port 80)
- **Database** — MySQL 8.0 (port 3306)

All three components are orchestrated via Docker Compose and deployed automatically
through a Jenkins CI/CD pipeline.

---

## Repository Structure

This repo is one of three sibling repositories. Clone all three at the same level:

```text
parent/
├── iot-devops/        ← this repo — Dockerfiles, Compose, Jenkins, scripts
├── iot-backend/       ← Java Spring Boot source + Dockerfile
└── iot-frontend/      ← Angular source + Dockerfile
```

```bash
git clone https://github.com/faridakhaled05/iot-devops.git
git clone https://github.com/Yosra-01/iot-backend.git
git clone https://github.com/SalmaaKhaledd/iot-frontend.git
```

---

## Files in This Repo

| File | Purpose |
|------|---------|
| `README.md` | Full setup and recreation instructions |
| `Dockerfile.db` | MySQL 8.0 custom image with database name baked in |
| `Dockerfile.jenkins` | Custom Jenkins image with Docker, Maven, Node, Compose installed |
| `docker-compose.yml` | Orchestrates all three containers with secrets and healthchecks |
| `docker-entrypoint.sh` | Backend entrypoint — reads Docker secret files and exports as env vars |
| `build-and-push.sh` | Manual script to build and push all three images to Docker Hub |
| `Jenkinsfile` | CI/CD pipeline definition — all stages from build to deploy |
| `.env.example` | Template for required environment variables — copy to `.env` and fill in |

---

## Prerequisites

- Docker Engine 20.10+ or Docker Desktop 4.x+ — [Install Docker](https://docs.docker.com/get-docker/)
- Git
- A Docker Hub account — [hub.docker.com](https://hub.docker.com)
- Java 21 and Maven (only needed if running backend locally outside Docker)
- Node.js 20 (only needed if running frontend locally outside Docker)

---

## ⚠️ Apple Silicon (Mac M1/M2/M3) — Read This First

This setup was originally developed on Apple Silicon. There are two things in the
configuration that are Mac-specific. If you are on Linux or Windows, read this section
before proceeding.

### 1. Docker Compose Binary in `Dockerfile.jenkins`

The `Dockerfile.jenkins` downloads the ARM64 build of Docker Compose:

```dockerfile
RUN curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-aarch64" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose
```

**If you are on Linux or Windows (x86_64):** replace `aarch64` with `x86_64`:

```dockerfile
RUN curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose
```

Using the wrong architecture binary causes `exec format error` at runtime.

### 2. The `buildx` Builder and `--platform` Flag in the Jenkinsfile

The Jenkinsfile uses a custom buildx builder named `native` and forces `--platform linux/amd64`.
This was necessary on Mac because Docker Desktop's default builder on Apple Silicon produces
multi-platform manifest lists that cannot be pushed to Docker Hub as standard images.

**If you are on Linux or Windows:** you likely do not need buildx at all. You can simplify
the Build & Push stages in the Jenkinsfile to use plain `docker build`:

```groovy
// Replace this (Mac-specific):
sh '''
    docker buildx build \
        --builder $BUILDER \
        --platform linux/amd64 \
        --load \
        -t $BACKEND_IMAGE \
        -f iot-backend/Dockerfile \
        iot-backend/
    docker push $BACKEND_IMAGE
'''

// With this (Linux/Windows):
sh '''
    docker build \
        -t $BACKEND_IMAGE \
        -f iot-backend/Dockerfile \
        iot-backend/
    docker push $BACKEND_IMAGE
'''
```

Also remove or skip Step 7 (Create the buildx Builder) in Part 2 below.

You can also remove the `BUILDER = 'native'` line from the `environment` block
in the Jenkinsfile since it will no longer be referenced.

---

## Part 1 — Manual Build and Run (Without Jenkins)

Use this path to verify the stack works before setting up CI/CD.

### Step 1 — Create the `.env` File

Inside `iot-devops/`, create a `.env` file. This file is gitignored — never commit it.

```bash
cd iot-devops
cp .env.example .env
```

Fill in the values with your own Docker Hub username and credentials:

```env
DOCKER_USERNAME=your_dockerhub_username
DOCKER_PASSWORD=your_dockerhub_password
IMAGE_TAG=v3.0
SECRETS_PATH=./secrets
```

### Step 2 — Create the Secrets Files

Docker Compose reads secrets from files, not plain environment variables.
Create the secrets directory and files manually:

```bash
mkdir -p secrets
printf '%s' 'your_mysql_root_password' > secrets/db_password.txt
printf '%s' 'your_jwt_secret_minimum_32_characters' > secrets/jwt_secret.txt
```

> ⚠️ The `secrets/` directory is gitignored. Never commit secret files.
> Use `printf '%s'` rather than `echo` to avoid writing a trailing newline
> into the secret file — a trailing newline causes silent auth failures.

### Step 3 — Build and Push All Images

Run the provided script from inside `iot-devops/`:

```bash
chmod +x build-and-push.sh
./build-and-push.sh
```

This script:
1. Validates that `.env` exists and all required variables are set
2. Validates that `iot-backend/` and `iot-frontend/` sibling directories exist
3. Logs into Docker Hub using your credentials from `.env`
4. Builds and pushes `iot-backend:v3.0`, `iot-frontend:v3.0`, `iot-db:v3.0`

To build images manually without the script (run from the parent directory):

```bash
docker build -f iot-backend/Dockerfile -t your_dockerhub_username/iot-backend:v3.0 iot-backend/
docker build -f iot-frontend/Dockerfile -t your_dockerhub_username/iot-frontend:v3.0 iot-frontend/
docker build -f iot-devops/Dockerfile.db -t your_dockerhub_username/iot-db:v3.0 iot-devops/
```

### Step 4 — Run the Stack with Docker Compose

From inside `iot-devops/`:

```bash
DOCKER_USERNAME=your_dockerhub_username \
IMAGE_TAG=v3.0 \
SECRETS_PATH=./secrets \
docker-compose up -d
```

Docker Compose starts containers in this order automatically:
1. `db` — waits until MySQL healthcheck passes (can take 20–30 seconds)
2. `backend` — starts only after db reports healthy
3. `frontend` — starts after backend

### Step 5 — Verify the Stack

Check all three containers are running:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected output — all three showing `Up`, db showing `(healthy)`:

```
iot-devops-db-1         Up 2 minutes (healthy)   0.0.0.0:3306->3306/tcp
iot-devops-backend-1    Up 1 minute              0.0.0.0:8080->8080/tcp
iot-devops-frontend-1   Up 1 minute              0.0.0.0:80->80/tcp
```

Verify the backend started correctly:

```bash
docker logs iot-devops-backend-1 --tail 20
```

Look for:
```
Started [ApplicationName] in X.XXX seconds
```

Verify the backend API is responding:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected: **HTTP 400** — server is up and input validation is working.

Open the frontend in your browser:

```
http://localhost
```

### Stopping the Stack

```bash
docker-compose down
```

To also remove the database volume (wipes all data):

```bash
docker-compose down -v
```

---

## Part 2 — Jenkins CI/CD Pipeline Setup

This is the automated path. The pipeline builds, tests, pushes, and deploys
the full stack automatically.

### Step 1 — Update `Dockerfile.jenkins` for Your Architecture

Before building, check the Docker Compose binary URL in `Dockerfile.jenkins`
and make sure it matches your CPU architecture:

- **Apple Silicon (Mac M1/M2/M3):** use `docker-compose-linux-aarch64` ← already in the file
- **Linux / Windows x86_64:** change to `docker-compose-linux-x86_64`

See the Apple Silicon section at the top of this README for the exact line to change.

### Step 2 — Build the Jenkins Image

From inside `iot-devops/`:

```bash
docker build -f Dockerfile.jenkins -t sensorix-jenkins .
```

This builds a custom Jenkins image that includes:
- Docker CLI (to run docker commands inside pipelines)
- Docker Compose v2.27.0 (architecture-specific binary)
- Maven (to build and test the Java backend)
- Node.js 20 + npm (to build and test the Angular frontend)

### Step 3 — Create the Jenkins Workspace Directory on the Host

This directory is mounted into the Jenkins container so that Docker Compose
can access secret files written by Jenkins during the Deploy stage.

```bash
mkdir -p /tmp/jenkins-workspace
```

> ⚠️ On Linux and Windows, `/tmp` may or may not be cleared on reboot depending
> on your OS configuration. If Jenkins loses its workspace directory, recreate it
> with the same command and restart the Jenkins container.

### Step 4 — Run the Jenkins Container

```bash
docker run -d \
  --name sensorix-jenkins \
  -p 9090:8080 \
  -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  -v /tmp/jenkins-workspace:/var/jenkins_home/workspace \
  sensorix-jenkins
```

Flag explanation:
- `-p 9090:8080` — Jenkins UI is at `localhost:9090` (internal Jenkins port is 8080)
- `-p 50000:50000` — Jenkins agent port for connecting future build agents
- `-v /var/run/docker.sock:/var/run/docker.sock` — mounts host Docker socket so Jenkins can run docker commands via the host daemon
- `-v jenkins_home:/var/jenkins_home` — named volume that persists Jenkins config, credentials, plugins, and job history across container restarts
- `-v /tmp/jenkins-workspace:/var/jenkins_home/workspace` — exposes the Jenkins workspace to the host filesystem so docker-compose can resolve secret file paths

### Step 5 — Fix Docker Socket Permissions

```bash
docker exec -u root sensorix-jenkins chmod 666 /var/run/docker.sock
```

Without this, Jenkins gets `permission denied` when trying to run docker commands.

> On Linux this is typically needed once after container creation.
> On Mac with Docker Desktop, the socket is recreated on every Docker restart
> so this command must be re-run after every restart.

### Step 6 — Get the Jenkins Initial Admin Password

```bash
docker exec sensorix-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Step 7 — Complete Jenkins Initial Setup

1. Open `http://localhost:9090` in your browser
2. Paste the initial admin password
3. Select **Install suggested plugins** and wait for installation to complete
4. Create your admin user
5. Accept the default Jenkins URL (`http://localhost:9090/`)

### Step 8 — Create the buildx Builder (Mac Only — Skip on Linux/Windows)

> **Linux/Windows users:** skip this step entirely and update the Jenkinsfile
> as described in the Apple Silicon section at the top of this README.

On Mac, Jenkins uses a custom buildx builder named `native` to produce
images that can be pushed to Docker Hub. Create it once on the host:

```bash
docker buildx create --name native --driver docker-container --use
docker buildx inspect native --bootstrap
```

Verify it was created:

```bash
docker buildx ls
```

You should see `native` listed with driver `docker-container`.

### Step 9 — Set the Global Environment Variable

Jenkins needs to know the host-side path of the workspace so docker-compose
can resolve secret file paths correctly.

1. Go to **Manage Jenkins → System**
2. Scroll to **Global properties**
3. Check **Environment variables**
4. Click **Add** and enter:
   - Name: `HOST_WORKSPACE_ROOT`
   - Value: `/tmp/jenkins-workspace`
5. Click **Save**

### Step 10 — Add Credentials to Jenkins

Go to **Manage Jenkins → Credentials → System → Global credentials → Add Credential**.

Add these three credentials. The IDs must match exactly — the Jenkinsfile references them by ID.

**Docker Hub credentials:**
- Kind: `Username with password`
- Username: your Docker Hub username
- Password: your Docker Hub password
- ID: `dockerhub-credentials`

**Database password:**
- Kind: `Secret text`
- Secret: your MySQL root password (choose any strong password)
- ID: `db-password`

**JWT secret:**
- Kind: `Secret text`
- Secret: your JWT signing secret (minimum 32 characters)
- ID: `jwt-secret`

### Step 11 — Update the Jenkinsfile Environment Block

Open `Jenkinsfile` in `iot-devops/` and set your Docker Hub username:

```groovy
environment {
    DOCKERHUB_USER  = 'your_dockerhub_username'   ← change this
    IMAGE_TAG       = 'v3.0'
    BUILDER         = 'native'
    ...
}
```

Commit and push the change to the `iot-devops` repo before creating the pipeline job.

### Step 12 — Create the Pipeline Job

1. Click **New Item**
2. Enter name: `iot-devops-pipeline`
3. Select **Pipeline** and click OK
4. Under **Pipeline**, set Definition to `Pipeline script from SCM`
5. Set SCM to `Git`
6. Repository URL: `https://github.com/faridakhaled05/iot-devops.git`
7. Branch: `*/main`
8. Script Path: `Jenkinsfile`
9. Click **Save**

### Step 13 — Run the Pipeline

Click **Build Now** on the pipeline page.

The pipeline runs these stages in order:

| Stage | What It Does |
|-------|-------------|
| Checkout Backend | Clones `iot-backend` repo into workspace |
| Checkout Frontend | Clones `iot-frontend` repo into workspace |
| Test (parallel) | Runs `mvn test` and `npm test` simultaneously |
| Build & Push Backend | Builds backend image, pushes to Docker Hub |
| Build & Push Frontend | Builds frontend image, pushes to Docker Hub |
| Deploy | Writes secret files, runs `docker-compose up --force-recreate` |
| Smoke Test | Verifies all containers are running and backend started |

### Step 14 — Verify the Pipeline

After the pipeline goes green:

```bash
# All three containers should be Up
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Backend log should contain "Started"
docker logs iot-devops-backend-1 --tail 20

# Verify backend API
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" -d '{}'
```

Open the frontend: `http://localhost`

---

## After Every Docker Restart

The Docker socket permissions reset when Docker restarts. Run this before
running the pipeline again:

```bash
docker exec -u root sensorix-jenkins chmod 666 /var/run/docker.sock
```

If the Jenkins container itself was stopped, start it first:

```bash
docker start sensorix-jenkins
docker exec -u root sensorix-jenkins chmod 666 /var/run/docker.sock
```

On Mac, also recreate the workspace directory if needed:

```bash
mkdir -p /tmp/jenkins-workspace
```

---

## Docker Hub Images

Images are pushed to Docker Hub under the account configured in `.env` and the Jenkinsfile.
Each team member uses their own Docker Hub account. The image names follow this pattern:

```
your_dockerhub_username/iot-backend:v3.0
your_dockerhub_username/iot-frontend:v3.0
your_dockerhub_username/iot-db:v3.0
```

To pull and run without building from source:

```bash
mkdir -p secrets
printf '%s' 'your_mysql_password' > secrets/db_password.txt
printf '%s' 'your_jwt_secret_32chars_minimum' > secrets/jwt_secret.txt

DOCKER_USERNAME=your_dockerhub_username \
IMAGE_TAG=v3.0 \
SECRETS_PATH=./secrets \
docker-compose up -d
```

---

## Troubleshooting

**Backend container exits immediately:**
```bash
docker logs iot-devops-backend-1
```
Most common cause: database not ready, or secret files empty/missing.
Check secret files:
```bash
cat secrets/db_password.txt
cat secrets/jwt_secret.txt
```

**`permission denied` on Docker socket in Jenkins:**
```bash
docker exec -u root sensorix-jenkins chmod 666 /var/run/docker.sock
```

**`exec format error` for docker-compose inside Jenkins:**
Wrong CPU architecture binary in `Dockerfile.jenkins`. Rebuild the Jenkins image
after correcting the URL — use `aarch64` for Mac, `x86_64` for Linux/Windows.

**`docker-compose: command not found` inside Jenkins:**
The compose download failed during image build. Rebuild Jenkins image and check
the build output for curl errors.

**Deploy stage fails — secret file not found:**
`HOST_WORKSPACE_ROOT` is not set or incorrect. Verify it is set to `/tmp/jenkins-workspace`
in Manage Jenkins → System → Global properties → Environment variables.
Also verify the directory exists on the host:
```bash
ls /tmp/jenkins-workspace
```

**buildx builder `native` not found (Mac only):**
```bash
docker buildx create --name native --driver docker-container --use
docker buildx inspect native --bootstrap
```

**Containers start but frontend shows blank page or API errors:**
```bash
docker logs iot-devops-backend-1 --tail 50
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" -d '{}'
```
Expected: HTTP 400. Anything else means the backend did not start correctly.

---

## Part 3 — Kubernetes Deployment 
 
This path runs the full stack on a local Kubernetes cluster via minikube, instead of
Docker Compose. All manifests referenced below already exist in this repo under `k8s/`.
 
### Before You Begin — What Must Already Be Done
 
This section assumes the following are already complete. If any of these aren't true yet,
go do them first — Part 3 will not work otherwise.
 
- **Part 1 has been completed at least once** — specifically, the three images
  (`iot-backend`, `iot-frontend`, `iot-db`) have been built and pushed to your Docker Hub
  account under a tag (e.g. `v4.0`). Kubernetes pulls images from Docker Hub (or loads them
  from your local Docker cache into minikube) — it does not build them itself.
- **The sibling directory structure exists**, i.e. `iot-devops`, `iot-backend`, and
  `iot-frontend` are all cloned at the same level under a common parent (see
  **Repository Structure** above). Referred to below as `~/sensorix/` for consistency,
  but any parent folder name works as long as all three repos sit alongside each other.
- **All commands below are run from inside `iot-devops/`** (e.g. `~/sensorix/iot-devops`),
  since that's where the `k8s/` directory lives. `cd` there first if you're not already.
- **Docker is installed and working** (already a prerequisite above).
- If working on WSL2/Windows: all commands run **inside the WSL Linux shell**, never CMD
  or PowerShell — `kubectl`, `minikube`, and `docker` in this setup are installed inside
  WSL and are not reachable from a native Windows terminal.
 
### Prerequisites
 
- `kubectl` 
- `minikube` 
- Docker (already required above)
### Step 1 — Install kubectl and minikube

The following commands are for Linux OS. If you're using a different OS, check [kubernetes guide for the installation](https://kubernetes.io/docs/tasks/tools/)
 
```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
 
# minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```
 
Verify both:
```bash
kubectl version --client
minikube version
```
 
### Step 2 — Start the Cluster
 
```bash
minikube start --driver=docker
```
 
This starts a single-node cluster using your existing Docker installation. First run
downloads a base image and may take a few minutes.
 
Verify:
```bash
minikube status
kubectl get nodes
```
 
You should see one node with status `Ready`.
 
### Step 3 — Create Your Real Secret File
 
The K8s Secret holding the database password and JWT secret is gitignored — only a
template is committed. Copy the template and fill in real values:
 
```bash
cp k8s/secret.yaml.example k8s/secret.yaml
nano k8s/secret.yaml
```
 
Replace the placeholder values with your actual MySQL root password and JWT secret —
ideally the same values already in `secrets/db_password.txt` and `secrets/jwt_secret.txt`,
so Compose and Kubernetes use identical credentials.
 
### Step 4 — Load Images Into Minikube
 
If you've already built and pushed the images per Part 1, load them directly from your
local Docker cache into minikube (faster and more reliable than pulling from Docker Hub again):
 
```bash
minikube image load your_dockerhub_username/iot-backend:v4.0
minikube image load your_dockerhub_username/iot-frontend:v4.0
minikube image load your_dockerhub_username/iot-db:v4.0
```
 
> If your image names in `k8s/*.yaml` reference a different Docker Hub username, update
> the `image:` field in `k8s/backend-deployment.yaml`, `k8s/frontend-deployment.yaml`, and
> `k8s/db-deployment.yaml` accordingly before applying.
 
### Step 5 — Apply the Manifests
 
Apply everything in the `k8s/` directory:
 
```bash
kubectl apply -f k8s/
```
 
This creates, in dependency order:
- The Secret (`sensorix-secrets`)
- The database PersistentVolumeClaim, Deployment, and Service
- The backend Deployment and Service (`iot-backend-svc`)
- The frontend Deployment and Service
### Step 6 — Verify the Deployment
 
```bash
kubectl get pods
kubectl get svc
kubectl get pvc
```
 
All Pods should reach `1/1 Ready` / `Running`. The database PVC should show `Bound`.
 
Check backend startup:
```bash
kubectl logs -l app=iot-backend-svc --tail 30
```
Look for `Started IotmonitorApplication` with no errors following it.
 
### Step 7 — Access the Application
 
The frontend Service is exposed via NodePort. Get the reachable URL:
 
```bash
minikube service frontend --url
```
 
Open the printed URL in your browser — this serves the full application, with the
frontend proxying API calls through to the backend and database running inside the cluster.

### Step 8 — Verify Rolling Updates
 
This demonstrates zero-downtime deployment — a new version replaces the old one without
any dropped requests, governed by the `RollingUpdate` strategy in `k8s/backend-deployment.yaml`
(`maxUnavailable: 1`, `maxSurge: 1`).
 
**Create a new tag to roll out.** No code change is required to demonstrate the mechanism —
retagging an existing image is sufficient, since Kubernetes reacts to the tag/template
changing, not to what's actually inside the image:
 
```bash
docker tag your_dockerhub_username/iot-backend:v4.0 your_dockerhub_username/iot-backend:v4.1
docker push your_dockerhub_username/iot-backend:v4.1
minikube image load your_dockerhub_username/iot-backend:v4.1
```
 
**Update the manifest** — open `k8s/backend-deployment.yaml` and change the `image:` line
to the new tag (`v4.1`).
 
**Apply and watch it live.** In one terminal, start watching before applying:
```bash
kubectl get pods -w
```
In a second terminal:
```bash
kubectl apply -f k8s/backend-deployment.yaml
```
 
You should see a new Pod (different ReplicaSet hash) come up, pass its readiness probe,
and only then does an old Pod begin terminating — repeating until both replicas are on
the new version. At no point does the Pod count drop below 1 or exceed 3.
 
Confirm the rollout completed cleanly:
```bash
kubectl rollout status deployment/iot-backend-svc
```
 
**To undo a rollout** (roll back to the previous version):
```bash
kubectl rollout undo deployment/iot-backend-svc
kubectl rollout status deployment/iot-backend-svc
```
 
---
 
### Step 9 — Verify Scaling
 
This demonstrates independently scaling one stateless service without affecting the rest
of the stack.
 
**Scale the backend up:**
```bash
kubectl scale deployment/iot-backend-svc --replicas=4
kubectl get pods
kubectl get deployment iot-backend-svc
```
You should see two additional Pods created on the same ReplicaSet (same image, same
config — just more copies), and the Deployment showing `4/4` ready.
 
**Scale back down to steady state:**
```bash
kubectl scale deployment/iot-backend-svc --replicas=2
kubectl get pods
```
 
> **Note on scaling the database:** `db` is intentionally kept at `replicas: 1` and should
> not be scaled up. Its PersistentVolumeClaim uses `ReadWriteOncePod`, which Kubernetes
> enforces at the scheduler level — a second Pod attempting to use the same volume will be
> rejected and stuck in `Pending` (confirm via `kubectl describe pod <pending-db-pod>` if
> ever tested). This is expected and correct: a single MySQL instance without configured
> replication cannot safely run as multiple writers against the same data.
 
---
 
### Tearing Down the Cluster Deployment
 
To remove all Kubernetes objects (keeps the database's persistent volume claim by default):
 
```bash
kubectl delete -f k8s/
```
 
To also delete the persisted database volume (wipes all data):
 
```bash
kubectl delete pvc db-pvc
```
 
To stop the entire minikube cluster:
 
```bash
minikube stop
```
 
To delete it completely (removes the cluster, not just stops it):
 
```bash
minikube delete
```
 
---

## Part 4 - Latest Sprint: OpenShift and Tekton CI/CD

This sprint moved the project from a local Kubernetes/Jenkins deployment model toward
live hosting on Red Hat OpenShift with OpenShift Pipelines (Tekton). The earlier
Docker Compose, Jenkins, and Minikube sections are still kept above as historical and
local setup paths. This section documents the newer deployment path.

### 4.1 OpenShift Manifest Migration

The existing Kubernetes manifests were duplicated into a separate OpenShift deployment
set instead of overwriting the Kubernetes baseline. The OpenShift manifests live under:

```text
deployment/
├── k8s/
└── openshift/
```

The OpenShift version keeps the same application shape:

- MySQL database Deployment, PVC, and internal Service
- Spring Boot backend Deployment and internal Service
- Angular/Nginx frontend Deployment and internal Service

The important OpenShift-specific changes were:

- Frontend external access now uses an OpenShift `Route`.
- Frontend Service exposure changed away from NodePort to `ClusterIP`.
- Internal service-to-service communication stays inside the OpenShift project.
- Route TLS uses edge termination with HTTP redirected to HTTPS.
- The Kubernetes manifests remain available for Minikube/local cluster work.

Apply the OpenShift manifests from `iot-devops` with:

```bash
oc apply -f deployment/openshift/
```

Verify the deployed resources:

```bash
oc get pods
oc get svc
oc get routes
oc rollout status deployment/backend
oc rollout status deployment/frontend
```

The public frontend URL is obtained from the Route:

```bash
oc get route frontend
```

### 4.2 Dockerfile Adjustments for OpenShift

The frontend and backend Dockerfiles were adjusted so the images run correctly under
OpenShift's stricter runtime model.

Backend changes focused on keeping the Spring Boot container compatible with OpenShift:

- The backend runs as the non-root `spring` user.
- Startup still uses `docker-entrypoint.sh`.
- The old local filesystem profile-picture storage path was no longer treated as the
  deployment storage strategy after profile images moved to Cloudflare R2.

Frontend changes focused on serving Angular through Nginx inside OpenShift:

- The frontend listens through the container port expected by the OpenShift Service.
- Nginx writable/cache paths are mounted or redirected so the container can run under
  OpenShift security constraints.
- The frontend Route sends public traffic to the frontend Service instead of relying on
  a NodePort.

### 4.3 OpenShift Secrets

Runtime secrets were moved into OpenShift Secrets rather than being stored in Git or in
pipeline YAML. The live backend expects database, JWT, and R2 values to be injected from
OpenShift.

Current secret-backed values include:

- MySQL root/application password
- JWT signing secret
- Docker Hub pull/push credentials for pipeline image publication
- SonarCloud token for analysis
- Cloudflare R2 profile-image storage configuration:
  - `IOT_R2_ACCOUNT_ID`
  - `IOT_R2_BUCKET`
  - `IOT_R2_ACCESS_KEY_ID`
  - `IOT_R2_SECRET_ACCESS_KEY`
  - `IOT_R2_PUBLIC_BASE_URL`

Only Secret references belong in manifests and pipelines. Secret values must never be
committed.

Useful inspection command:

```powershell
oc set env deployment/backend --list | Select-String "R2|IOT_R2"
```

### 4.4 Migration from Jenkins to Tekton

The CI/CD workflow was migrated from the older Jenkins pipeline to OpenShift Pipelines
(Tekton) so the build, validation, image publishing, smoke deployment, and live rollout
run inside OpenShift.

Pipeline definitions are stored beside the application code, not in `iot-devops`.
This keeps each service's CI/CD behavior versioned with the code it builds.

```text
iot-backend/.tekton/
|-- backend-pipeline.yaml
|-- push.yaml
`-- pull-request.yaml

iot-frontend/.tekton/
|-- frontend-pipeline.yaml
|-- push.yaml
`-- pull-request.yaml
```

The backend `.tekton` directory contains:

| File | Purpose |
|------|---------|
| `backend-pipeline.yaml` | The reusable Tekton `Pipeline` definition for backend CI/CD. It clones the repo, runs Maven tests, runs SonarCloud analysis, builds and pushes the backend image, deploys a smoke backend, runs backend sanity checks, publishes release tags, updates the live backend Deployment, and cleans up smoke resources. |
| `push.yaml` | Pipeline-as-Code `PipelineRun` template for pushes to `main`. It sets `deploy: "true"`, mounts the Docker Hub credentials workspace, and allows the pipeline to publish images and update the live backend. |
| `pull-request.yaml` | Pipeline-as-Code `PipelineRun` template for pull requests targeting `main`. It sets `deploy: "false"` so PRs validate code without publishing production tags or changing the live backend Deployment. |

The frontend `.tekton` directory contains:

| File | Purpose |
|------|---------|
| `frontend-pipeline.yaml` | The reusable Tekton `Pipeline` definition for frontend CI/CD. It clones the repo, runs Angular tests with coverage, runs SonarCloud analysis, builds and pushes the frontend image, deploys a smoke frontend Route, runs Selenium sanity checks, publishes release tags, updates the live frontend Deployment, and cleans up smoke resources. |
| `push.yaml` | Pipeline-as-Code `PipelineRun` template for pushes to `main`. It sets `deploy: "true"`, mounts Docker Hub credentials, and allows the validated frontend image to roll out live. |
| `pull-request.yaml` | Pipeline-as-Code `PipelineRun` template for pull requests targeting `main`. It sets `deploy: "false"` so PRs run validation without changing the live frontend Route or Deployment. |

Pipeline-as-Code integration is handled through annotations in each `push.yaml` and
`pull-request.yaml` file. Those annotations tell OpenShift Pipelines:

- which Git event should trigger the run (`push` or `pull_request`)
- which branch should match (`main`)
- which pipeline file to load (`.tekton/backend-pipeline.yaml` or `.tekton/frontend-pipeline.yaml`)
- which Tekton task is required for cloning (`git-clone`)
- how many old runs to keep (`max-keep-runs: "2"`)

Pipeline-as-Code injects Git context into each run using template variables:

- `{{ repo_url }}` becomes the repository URL.
- `{{ revision }}` becomes the commit SHA or PR revision.
- `{{ git_auth_secret }}` becomes the Git authentication Secret used by `git-clone`.

Each PipelineRun uses the OpenShift `pipeline` service account and a PVC-backed
`source` workspace. Push runs also mount the `dockerhub-credentials` workspace so the
pipeline can push validated images. PR runs omit Docker publishing credentials where
deployment is not needed.

Both repositories therefore use two Pipeline-as-Code triggers:

| Trigger | Event | Target | Deploys live? | Purpose |
|---------|-------|--------|---------------|---------|
| `push.yaml` | `push` | `main` | Yes | Build, validate, publish, smoke-test, and roll out the live Deployment |
| `pull-request.yaml` | `pull_request` | `main` | No | Validate PR code without changing the live Deployment |

The `deploy` pipeline parameter controls the difference:

- `deploy: "true"` for push to `main`
- `deploy: "false"` for pull requests

### 4.5 Backend Tekton Pipeline Stages

The backend pipeline has 10 stages:

| Stage | What happens |
|-------|--------------|
| 1. `fetch-repository` | Clones the backend repository at the requested revision using Pipeline-as-Code Git auth. |
| 2. `test-backend` | Runs Maven tests and produces backend test/coverage inputs before image build. |
| 3. `sonar-analysis` | Runs SonarCloud analysis and quality gate checks. This integration is non-blocking for deployment, so diagnostics are collected without making SonarCloud availability the only deployment gate. |
| 4. `calculate-version` | Computes immutable, version, commit, and latest Docker image tags for traceable releases. |
| 5. `build-and-push` | Builds the backend image from the repo Dockerfile and pushes the immutable image to Docker Hub using the Docker config Secret. |
| 6. `deploy-smoke-backend` | Creates a temporary `backend-smoke` Deployment and Service using the candidate image, Docker profile, DB Secret, JWT Secret, scheduler-disabled cron values, and R2 Secret references. |
| 7. `backend-sanity-checks` | Runs backend API sanity checks against the smoke deployment before the image is allowed to progress. |
| 8. `publish-additional-tags` | Copies the already-validated immutable image to version, commit, and `latest` tags. |
| 9. `deploy-backend` | Updates the live `backend` Deployment image and patches required R2 Secret references into the live Deployment before rollout. |
| 10. `cleanup-smoke-backend` | Deletes the temporary backend smoke Deployment and Service in a `finally` cleanup path. |

Important backend safeguards:

- Smoke deployment uses the same R2 Secret keys as the live backend.
- The pipeline validates required R2 Secret keys before applying the smoke Deployment.
- Scheduler cron values are disabled in smoke so temporary Pods do not run background polling jobs.
- Readiness and liveness probes must pass before rollout is considered healthy.
- Rollout diagnostics are printed if the smoke or live Deployment fails.

### 4.6 Frontend Tekton Pipeline Stages

The frontend pipeline also has 10 stages:

| Stage | What happens |
|-------|--------------|
| 1. `fetch-repository` | Clones the frontend repository at the requested revision using Pipeline-as-Code Git auth. |
| 2. `test-frontend` | Runs Angular unit tests with coverage before image build. |
| 3. `sonar-analysis` | Runs SonarCloud analysis and quality gate checks. This is non-blocking in the same way as the backend pipeline. |
| 4. `calculate-version` | Computes immutable, version, commit, and latest Docker image tags. |
| 5. `build-and-push` | Builds the Angular/Nginx image and pushes the immutable image to Docker Hub. |
| 6. `deploy-smoke-frontend` | Creates a temporary `frontend-smoke` Deployment, Service, and Route using the candidate image and OpenShift-compatible Nginx config. |
| 7. `selenium-sanity-checks` | Runs Selenium smoke/sanity tests against the smoke Route with configured frontend and API base URLs. |
| 8. `publish-additional-tags` | Publishes additional version, commit, and `latest` tags only after smoke validation passes. |
| 9. `deploy-frontend` | Updates the live `frontend` Deployment image and waits for OpenShift rollout success. |
| 10. `cleanup-smoke-frontend` | Deletes the temporary frontend smoke Deployment, Service, and Route in a `finally` cleanup path. |

Important frontend safeguards:

- PR runs validate code and SonarCloud without deploying live.
- Push runs validate the smoke frontend first, then promotes the candidate image.
- Selenium tests run against the smoke Route instead of the live Route.
- The live frontend uses the OpenShift Route mechanism, not NodePort.

### 4.7 Current Deployment Flow

For a push to `main`, the current production path is:

```text
GitHub push
-> Pipeline-as-Code trigger
-> Tekton PipelineRun in OpenShift
-> clone repo
-> unit tests and coverage
-> non-blocking SonarCloud analysis
-> calculate image tags
-> build and push immutable image
-> deploy temporary smoke environment
-> run sanity checks
-> publish release tags
-> update live OpenShift Deployment
-> cleanup smoke resources
```

For a pull request, the flow stops before live deployment:

```text
GitHub pull request
-> Pipeline-as-Code trigger
-> Tekton PipelineRun in OpenShift
-> clone repo
-> unit tests and coverage
-> non-blocking SonarCloud analysis
-> no live Deployment update
```

This gives PRs fast validation while keeping live rollouts restricted to merged changes
on `main`.

### 4.8 Latest Sprint Outcome

By the end of the sprint:

- The Kubernetes deployment was preserved and duplicated into an OpenShift-specific path.
- NodePort exposure was removed from the OpenShift frontend path and replaced with Routes.
- Dockerfiles were adjusted for live OpenShift runtime behavior.
- Backend, frontend, and database workloads were deployed to OpenShift.
- Runtime secrets were added to OpenShift and referenced from manifests/pipelines.
- Jenkins was superseded by Tekton/OpenShift Pipelines for live CI/CD.
- Backend and frontend each received a 10-stage pipeline with smoke deployments,
  sanity checks, image promotion, live rollout, and cleanup.
- Push and pull-request triggers were added for both repositories.
- SonarCloud analysis was integrated as a non-blocking quality signal.

---

## Security Notes

- Never commit `.env`, `secrets/`, or any file containing passwords or tokens
- `.env`, `secrets/`, and `k8s/secret.yaml` are all listed in `.gitignore`
- Jenkins credentials are encrypted at rest using the master key stored in `jenkins_home`
- Secret values are masked as `****` in all Jenkins build logs
- Docker Compose secrets are mounted as read-only files at `/run/secrets/` inside containers — never visible via `docker inspect`
- Kubernetes Secrets are base64-encoded and access-controlled via RBAC — not encrypted at rest by default
- The backend runs as a non-root `spring` user inside its container
