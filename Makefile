# General variables
APP_NAME        ?= myapp
VERSIONS        ?= v1 v2 v3
MINIKUBE_CPUS   ?= 4
MINIKUBE_MEMORY ?= 8192
ISTIO_PROFILE   ?= demo
K8S_PLATFORM    ?= minikube

# Namespaces
NS_AB               ?= ab-demo
NS_ROLLOUT          ?= 02-rollout-demo
NS_ROLLOUT_HEADER   ?= 03-rollout-header-split-demo
NS_ROLLOUT_METRICS  ?= 04-argo-rollout-metrics

# Paths to yamls
MANIFESTS_DIR   	?= manifests
DIR_AB          	?= $(MANIFESTS_DIR)/01-manual-ab/k8s
DIR_ROLLOUT     	?= $(MANIFESTS_DIR)/02-argo-rollout/k8s
DIR_ROLLOUT_HDR 	?= $(MANIFESTS_DIR)/03-argo-rollout-manual-beta/k8s
DIR_ROLLOUT_METRICS ?= $(MANIFESTS_DIR)/04-argo-rollout-metrics/k8s



# Useful stuff

.PHONY: help
help:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables:"
	@echo "  K8S_PLATFORM       Platform: minikube|docker-desktop|auto (default: auto)"
	@echo "  APP_NAME           Application name (default: myapp)"
	@echo "  VERSIONS           Space-separated app versions (default: v1 v2 v3)"

.PHONY: check-deps
check-deps: ## Check required tools are installed (macos/linux only, requires `command` builtin)
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "❌ docker not found"; exit 1; }
	@command -v istioctl >/dev/null 2>&1 || { echo "❌ istioctl not found"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "❌ helm not found"; exit 1; }
ifeq ($(K8S_PLATFORM),minikube)
	@command -v minikube >/dev/null 2>&1 || { echo "❌ minikube not found"; exit 1; }
endif
	@echo "✓ All dependencies satisfied"

# ──────────────────────────────────────────────────────────────────────────────
#  Platform abstraction
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: k8s-ensure-running
k8s-ensure-running: ## Ensure Kubernetes cluster is running (platform-aware)
ifeq ($(K8S_PLATFORM),minikube)
	@minikube status >/dev/null 2>&1 || minikube start --cpus=$(MINIKUBE_CPUS) --memory=$(MINIKUBE_MEMORY)
	@minikube status
else ifeq ($(K8S_PLATFORM),docker-desktop)
	@echo "✓ Using Docker Desktop Kubernetes. Please ensure it's enabled in Docker Desktop settings."
	@kubectl cluster-info >/dev/null 2>&1 || (echo "❌ Kubernetes not accessible. Is Docker Desktop running?" && exit 1)
else
	@echo "⚠ Unknown platform '$(K8S_PLATFORM)'. Assuming kubectl is configured."
	@kubectl cluster-info >/dev/null 2>&1 || (echo "❌ Cannot reach Kubernetes cluster" && exit 1)
endif

install-istio: k8s-ensure-running ## Install Istio if not installed
	@istioctl version --remote >/dev/null 2>&1 || istioctl install --set profile=$(ISTIO_PROFILE) -y

install-rollouts: ## Install Argo Rollouts into the cluster
	kubectl create ns argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	kubectl argo rollouts version >/dev/null 2>&1 || (echo "❌ Error. Please refer to https://argo-rollouts.readthedocs.io/en/stable/installation/#manual" && exit 1)

install-prometheus: ## Install kube-prometheus-stack (Prometheus + Grafana) using Helm
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm install prometheus-stack prometheus-community/kube-prometheus-stack


one-time-setup: check-deps k8s-ensure-running install-istio install-rollouts install-prometheus ## One time setup for demos (minikube + istio + argo rollouts)
	@echo "One-time setup completed. You can now run 'make 0X-XX' to deploy the demos. Refer to `make help` for more details."


load-images: $(addprefix build-app-,$(VERSIONS)) # Old target, deprecated in favor of building inside minikube.
ifeq ($(K8S_PLATFORM),minikube)
	@for v in $(VERSIONS); do \
		minikube image rm $(APP_NAME):$$v || true; \
		minikube image load $(APP_NAME):$$v --overwrite=true; \
	done
else
	@# Docker Desktop: images built locally are automatically visible to k8s
	@echo "✓ Image $(IMAGE) is already available to Kubernetes (Docker Desktop)"
endif

# ──────────────────────────────────────────────────────────────────────────────
#  Build app 
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: build-app-%
build-app-%: ## Build image myapp:vX (auto-detects platform)
ifeq ($(K8S_PLATFORM),minikube)
	@eval $$(minikube docker-env) && \
	echo "→ Building $(APP_NAME):$* in Minikube..." && \
	cd app && docker build --build-arg APP_VERSION=$* -t $(APP_NAME):$* .
else
	@echo "→ Building $(APP_NAME):$* (Docker Desktop)..." && \
	cd app && docker build --build-arg APP_VERSION=$* -t $(APP_NAME):$* .
endif

.PHONY: build-all
build-all: $(addprefix build-app-,$(VERSIONS)) ## Build all versions

# ──────────────────────────────────────────────────────────────────────────────
#  Demo targets
# ──────────────────────────────────────────────────────────────────────────────

01-up: k8s-ensure-running build-all ## Deploy A/B Testing Demo.
	kubectl create ns $(NS_AB) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label ns $(NS_AB) istio-injection=enabled --overwrite
	kubectl delete -f $(DIR_AB) --ignore-not-found=true
	kubectl apply -f $(DIR_AB)

01-down: ## Delete A/B Testing Demo.
	kubectl delete namespace $(NS_AB) --ignore-not-found=true

02-up: k8s-ensure-running build-all ## Deploy Argo Rollouts demo
	kubectl create ns $(NS_ROLLOUT) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label ns $(NS_ROLLOUT) istio-injection=enabled --overwrite
	kubectl delete -f $(DIR_ROLLOUT) --ignore-not-found=true
	kubectl apply -f $(DIR_ROLLOUT)

02-deploy-v2: ## Deploy version 2 of the app in Argo Rollouts demo
	kubectl argo rollouts set image myapp myapp=myapp:v2 -n $(NS_ROLLOUT)

02-watch: ## Watch the Argo Rollouts demo rollout status
	kubectl argo rollouts get rollout myapp -n $(NS_ROLLOUT) --watch

02-down: ## Delete Argo Rollouts demo
	kubectl delete ns $(NS_ROLLOUT) --ignore-not-found=true

03-up: k8s-ensure-running build-all ## Deploy Argo Rollouts header split demo
	kubectl create ns $(NS_ROLLOUT_HEADER) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label ns $(NS_ROLLOUT_HEADER) istio-injection=enabled --overwrite
	kubectl delete -f $(DIR_ROLLOUT_HDR) --ignore-not-found=true
	kubectl apply -f $(DIR_ROLLOUT_HDR)

03-deploy-v2: ## Deploy version 2 of the app in Argo Rollouts header split demo
	kubectl argo rollouts set image myapp myapp=myapp:v2 -n $(NS_ROLLOUT_HEADER)

03-promote-deploy: ## Promote deploy the Argo Rollouts header split demo to the next step (if it's paused)
	kubectl argo rollouts promote myapp -n $(NS_ROLLOUT_HEADER)

03-watch: ## Watch the Argo Rollouts header split demo rollout status
	kubectl argo rollouts get rollout myapp -n $(NS_ROLLOUT_HEADER) --watch

03-down: ## Delete header-based demo
	kubectl delete ns $(NS_ROLLOUT_HEADER) --ignore-not-found=true

04-up: k8s-ensure-running build-all ## Deploy Argo Rollouts metrics demo
	kubectl create ns $(NS_ROLLOUT_METRICS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label ns $(NS_ROLLOUT_METRICS) istio-injection=enabled --overwrite
	kubectl delete -f $(DIR_ROLLOUT_METRICS) --ignore-not-found=true
	kubectl apply -f $(DIR_ROLLOUT_METRICS)

04-deploy-v2: ## Deploy version 2 of the app in Argo Rollouts metrics demo
	kubectl argo rollouts set image myapp myapp=myapp:v2 -n $(NS_ROLLOUT_METRICS)

04-deploy-v3: ## Deploy version 3 of the app in Argo Rollouts metrics demo
	kubectl argo rollouts set image myapp myapp=myapp:v3 -n $(NS_ROLLOUT_METRICS)

04-promote-deploy: ## Promote deploy the Argo Rollouts metrics demo to the next step (if it's paused)
	kubectl argo rollouts promote myapp -n $(NS_ROLLOUT_METRICS)

04-watch: ## Watch the Argo Rollouts metrics demo rollout status
	kubectl argo rollouts get rollout myapp -n $(NS_ROLLOUT_METRICS) --watch

04-down: ## Delete metrics-based demo
	kubectl delete ns $(NS_ROLLOUT_METRICS) --ignore-not-found=true


all-down: 01-down 02-down 03-down 04-down ## Delete all demos
