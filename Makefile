
build-app-v1:
	@echo "Building the application..."
	cd app
	docker build --build-arg APP_VERSION=v1 -t myapp:v1 app/
	@echo "Built v1 image successfully."

build-app-v2:
	@echo "Building the application..."
	cd app
	docker build --build-arg APP_VERSION=v2 -t myapp:v2 app/
	@echo "Built v2 image successfully."

build-01: build-app-v1 build-app-v2
	@echo "Building AB Demo..."
	minikube start --cpus=4 --memory=8192   
	istioctl install --set profile=demo -y
	# load local images into minikube
	eval $(minikube docker-env -u)
	minikube image load myapp:v1
	minikube image load myapp:v2

	kubectl create ns ab-demo
	kubectl label ns ab-demo istio-injection=enabled --overwrite
	kubectl apply -f 01-manual-ab/k8s/

delete-01:
	@echo "Deleting AB Demo..."
	kubectl delete namespace ab-demo
	minikube stop


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
	kubectl apply -f 02-argo-rollout/k8s/