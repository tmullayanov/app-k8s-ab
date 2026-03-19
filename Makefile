# General variables
APP_NAME        ?= myapp
VERSIONS        ?= v1 v2
MINIKUBE_CPUS   ?= 4
MINIKUBE_MEMORY ?= 8192
ISTIO_PROFILE   ?= demo

# Namespaces
NS_AB               ?= ab-demo
NS_ROLLOUT          ?= rollout-demo
NS_ROLLOUT_HEADER   ?= rollout-header-demo

# Paths to yamls
MANIFESTS_DIR   ?= manifests
DIR_AB          ?= $(MANIFESTS_DIR)/01-manual-ab/k8s
DIR_ROLLOUT     ?= $(MANIFESTS_DIR)/02-argo-rollout/k8s
DIR_ROLLOUT_HDR ?= $(MANIFESTS_DIR)/03-argo-rollout-manual-beta/k8s


# Useful stuff

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

minikube-up:
	@minikube status >/dev/null 2>&1 || minikube start --cpus=$(MINIKUBE_CPUS) --memory=$(MINIKUBE_MEMORY)
	@minikube status

istio-install: minikube-up
	@istioctl version --remote >/dev/null 2>&1 || istioctl install --set profile=$(ISTIO_PROFILE) -y

docker-env: minikube-up ## Подключить docker-env minikube
	@eval $$(minikube -p minikube docker-env)

load-images: docker-env $(addprefix build-app-,$(VERSIONS)) ## Загрузить все образы в minikube
	@for v in $(VERSIONS); do \
		minikube image load $(APP_NAME):$$v; \
	done

# ──────────────────────────────────────────────────────────────────────────────
#  Build app 
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: build-app-%
build-app-%: ## Собрать образ myapp:vX
	@echo "Building $(APP_NAME):$* ..."
	@cd app && docker build --build-arg APP_VERSION=$* -t $(APP_NAME):$* .

.PHONY: build-all
build-all: $(addprefix build-app-,$(VERSIONS)) ## Собрать все версии

# ──────────────────────────────────────────────────────────────────────────────
#  Demo 01: Manual A/B Testing
# ──────────────────────────────────────────────────────────────────────────────

01-up: build-all minikube-up istio-install load-images
	kubectl create ns $(NS_AB) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label ns $(NS_AB) istio-injection=enabled --overwrite
	kubectl apply -f $(DIR_AB)

01-down:
	kubectl delete namespace $(NS_AB) --ignore-not-found=true

build-02: build-app-v1 build-app-v2
	@echo "Building Argo Rollout Demo..."
	minikube start --cpus=4 --memory=8192
	istioctl install --set profile=demo -y
	kubectl create namespace argo-rollouts
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

	
	eval $(minikube docker-env -u)
	minikube image load myapp:v1
	minikube image load myapp:v2


	kubectl create ns 02-rollout-demo
	kubectl label ns 02-rollout-demo istio-injection=enabled --overwrite
	kubectl apply -f manifests/02-argo-rollout/k8s/

delete-02:
	@echo "Deleting Argo Rollout Demo..."
	kubectl delete namespace 02-rollout-demo
	minikube stop

build-flagger-experimental: build-app-v1 build-app-v2
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

build-03: build-app-v1 build-app-v2
	@echo "Building Argo Rollout Header Split Demo..."
	minikube start --cpus=4 --memory=8192
	istioctl install --set profile=demo -y

	eval $(minikube docker-env -u)
	minikube image load myapp:v1
	minikube image load myapp:v2

	kubectl apply -f manifests/03-argo-rollout-manual-beta/k8s/

delete-03:
	@echo "Deleting Argo Rollout Header Split Demo..."
	kubectl delete namespace 03-rollout-header-split-demo
	minikube stop