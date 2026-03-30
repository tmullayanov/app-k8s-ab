# General variables
APP_NAME        ?= myapp
VERSIONS        ?= v1 v2 v3
MINIKUBE_CPUS   ?= 4
MINIKUBE_MEMORY ?= 8192
ISTIO_PROFILE   ?= demo

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
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

minikube-up: ## up minikube if not running. Runs with default profile and default driver
	@minikube status >/dev/null 2>&1 || minikube start --cpus=$(MINIKUBE_CPUS) --memory=$(MINIKUBE_MEMORY)
	@minikube status

istio-install: minikube-up ## Install Istio if not installed
	@istioctl version --remote >/dev/null 2>&1 || istioctl install --set profile=$(ISTIO_PROFILE) -y

install-rollouts:
	kubectl create ns argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

install-prometheus:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm install prometheus-stack prometheus-community/kube-prometheus-stack


one-time-setup: minikube-up istio-install install-rollouts install-prometheus ## One time setup for demos (minikube + istio + argo rollouts)
	@echo "One-time setup completed. You can now run 'make 0X-XX' to deploy the demos. Refer to `make help` for more details."

docker-env: minikube-up 
	@eval $$(minikube docker-env)

load-images: docker-env $(addprefix build-app-,$(VERSIONS)) ## Загрузить все образы в minikube
	@for v in $(VERSIONS); do \
		minikube image rm $(APP_NAME):$$v || true; \
		minikube image load $(APP_NAME):$$v --overwrite=true; \
	done

# ──────────────────────────────────────────────────────────────────────────────
#  Build app 
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: build-app-%
build-app-%: docker-env## Собрать образ myapp:vX
	@echo "Building $(APP_NAME):$* ..."
	@cd app && docker build --build-arg APP_VERSION=$* -t $(APP_NAME):$* .

.PHONY: build-all
build-all: $(addprefix build-app-,$(VERSIONS)) ## build all versions

# ──────────────────────────────────────────────────────────────────────────────
#  Demo 01: Manual A/B Testing
# ──────────────────────────────────────────────────────────────────────────────

01-up: build-all minikube-up istio-install load-images ## Deploy A/B Testing Demo.
	kubectl create ns $(NS_AB) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label ns $(NS_AB) istio-injection=enabled --overwrite
	kubectl delete -f $(DIR_AB) --ignore-not-found=true
	kubectl apply -f $(DIR_AB)

01-down: ## Delete A/B Testing Demo.
	kubectl delete namespace $(NS_AB) --ignore-not-found=true

02-up: build-all minikube-up istio-install load-images ## Deploy Argo Rollouts demo
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

03-up: build-all minikube-up istio-install load-images ## Deploy Argo Rollouts header split demo
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

04-up: build-all minikube-up istio-install load-images ## Deploy Argo Rollouts metrics demo
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


UNSTABLE_build-flagger-experimental: build-app-v1 build-app-v2
	@echo "Building Flagger Demo..."
	minikube start --cpus=4 --memory=8192
	istioctl install --set profile=demo -y
	kubectl create namespace flagger
	# kubectl apply -n flagger -f https://flagger.app/install/flagger-istio.yaml

	eval $(minikube docker-env -u)
	minikube image load myapp:v1
	minikube image load myapp:v2

	kubectl create ns 03-flagger-demo
	kubectl label ns 03-flagger-demo istio-injection=enabled --overwrite
	# kubectl apply -f manifests/03-flagger/k8s/
