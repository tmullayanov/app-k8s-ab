# Canary Deployment & Argo Rollouts Demo

Case-study and demonstration of various Kubernetes deployment strategies using Istio and Argo Rollouts.

## 📋 About the Application

A simple FastAPI application with one main endpoint:

| Endpoint | Description |
|----------|-------------|
| `/` | Returns application version and header information |
| `/health` | Health check for Kubernetes |
| `/metrics` | Prometheus metrics for Argo Rollouts |

## 🚀 Quick Start

### 1. Check Environment

```bash
make check-deps
```

### 2. One-Time Setup (First Run Only)

```bash
make one-time-setup
# make docker-desktop one-time-setup for Docker Desktop setups
```

Installs: Istio, Argo Rollouts, Prometheus Stack

### 3. Run Demos

```bash
# Demo 01: Manual A/B Testing
make 01-up
# or 
make docker-desktop 01-up # for Docker Desktop k8s

# Demo 02: Argo Rollouts (canary)
make 02-up
# or 
make docker-desktop 02-up # for Docker Desktop k8s

# Demo 03: Header-based splitting
make 03-up
# or 
make docker-desktop 03-up # for Docker Desktop k8s


# Demo 04: Metrics-based rollouts
make 04-up
# or 
make docker-desktop 04-up # for Docker Desktop k8s
```

### 4. Cleanup

```bash
# Remove specific demo
make 01-down

# Remove all demos
make all-down
```

## 🖥 Typical Workflow

Recommended to use **two terminals**:

### Terminal 1: Observation (watch)

Don't forget to specify docker-desktop if needed!

```bash
# For demo 02
make 02-up
make 02-watch

# For demo 03
make 03-up
make 03-watch

# For demo 04
make 04-up
make 04-watch
```

### Terminal 2: Deployment Management
```bash
# Terminal 1 - Observe
$ make 03-deploy-v2
$ make 03-promote-deploy
```

# Demo 04

```bash
$ make 04-deploy-v2 # v2 is faulty, rollout will abort due to bad metrics
# then, for further (successful!) deployment
$ make 04-deploy-v3 # until rollout goes into Paused state
$ make 04-promote-deploy 
```

---
```bash
# Deploy new version for 02
make 02-deploy-v2

# Deploy new version for 03
make 03-deploy-v2
# Promote rollout (when paused)
make 03-promote-deploy

# Deploy v3 (for demo 04)
make 04-deploy-v2 # v2 is faulty, rollout will abort due to bad metrics
# then, for further (successful!) deployment
make 04-deploy-v3 # until rollout goes into Paused state
make 04-promote-deploy # To advance it from paused state
```

### Terminal 3: Traffic Generation (Optional)

```bash
# Run request generation script: first arg is demo identifier (01, 02, 03 or 04)
./run-requests.sh 02 http://<address> # # istio ingress address
```

For minikube 

## 📦 Platforms

Makefile automatically detects the platform. Supported:

| Platform | Command |
|----------|---------|
| Minikube (auto) | `make 01-up` |
| Minikube (explicit) | `make minikube 01-up` |
| Docker Desktop | `make docker-desktop 01-up` |
| Explicit | `make K8S_PLATFORM=minikube 01-up` |

## 🎯 Demo Descriptions

| Demo | Strategy | Description |
|------|----------|-------------|
| **01** | Manual A/B | Manual traffic management via Istio VirtualService |
| **02** | Canary | Automatic canary deployment with Argo Rollouts |
| **03** | Header-based | Traffic splitting by header (beta testing) with Argo Rollouts |
| **04** | Metrics-based + Header-based | Rollout based on metrics (error rate, latency) with Argo Rollouts |

## 🛠 Available Commands

```bash
make help              # Show all available targets
make check-deps        # Check installed dependencies
make one-time-setup    # Install all components (Istio, Argo, Prometheus)
make build-all         # Build all application versions (v1, v2, v3)
make all-down          # Remove all demo namespaces
```

## 📁 Structure

```
.
├── Makefile                    # Main commands
├── run-requests.sh            # Traffic generation script
├── app/                       # FastAPI application
└── manifests/
    ├── 01-manual-ab/          # Demo 01
    ├── 02-argo-rollout/       # Demo 02
    ├── 03-argo-rollout-manual-beta/  # Demo 03
    └── 04-argo-rollout-metrics/      # Demo 04
```

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `K8S_PLATFORM` | `auto` | `minikube`, `docker-desktop`, or `auto` |
| `APP_NAME` | `myapp` | Application name for images |
| `VERSIONS` | `v1 v2 v3` | Versions to build |
| `MINIKUBE_CPUS` | `4` | CPUs for Minikube |
| `MINIKUBE_MEMORY` | `8192` | Memory for Minikube (MB) |

Usage example:
```bash
make K8S_PLATFORM=docker-desktop APP_NAME=mydemo 02-up
```

## ⚠️ Requirements

- `kubectl`
- `docker`
- `istioctl`
- `helm`
- `minikube` (Minikube only)
- `kubectl-argo-rollouts` (for watch/promote commands)

## 🎬 Example Session (Demo 02)

```bash
# Terminal 1 - Observation
$ make 02-up
$ make 02-watch

# Terminal 2 - Deployment
$ make 02-deploy-v2
# Watch in Terminal 1 as rollout progresses

# Terminal 3 - Traffic (optional)
$ ./run-requests.sh 02 http://localhost:8080
```

## Demo 03

```bash
# Terminal 1 - Observe
$ make 
$ make 03-deploy-v2
$ make 03-promote-deploy
```

## Demo 04

```bash
$ make 04-deploy-v2 # v2 is faulty, rollout will abort due to bad metrics
# then, for further (successful!) deployment
$ make 04-deploy-v3 # until rollout goes into Paused state
$ make 04-promote-deploy # promote deploy that's paused into full rollout.
```

---

# Misc

## Toy application

```sh
cd app
docker build  --build-arg APP_VERSION=v0 -t myapp:v0 .

# actually, any string might be passed to the image.
# it will be used in response of it's main endpoint.
# k8s manifests, though, will use v1, v2 and v3
```

The image might be run separately.

```sh
docker run -d -p 8000:8000 myapp:v0

curl http://localhost:8000/ # beta_tester: false in response
curl -H "x-role: beta_tester" http://localhost:8000/ # beta_tester: true in response.
```

## Istio ingress address via minikube.

```sh
> minikube ip
10.10.10.10  # just an example
```

This is the address we should make our requests at.

```sh
kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.109.212.78   10.109.212.78   15021:31538/TCP,80:31962/TCP,443:30715/TCP,31400:31990/TCP,15443:31540/TCP   81m

```

Here, we see that port `80` was mapped to `31962`.
`80` port is set to be entry-point to our ingress, as it is defined in `k8s/05-gateway.yaml`.
Thus, the entry point of our minikube setup is derived from `minikube ip` and mapped port.

---

**Happy rolling! 🚀**
