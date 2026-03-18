
build-app:
	@echo "Building the application..."
	cd app
	docker build -t myapp:latest .

build-ab-demo: build-app
	@echo "Building AB Demo..."
	minikube start --cpus=4 --memory=8192   
	istioctl install --set profile=demo -y
	kubectl create ns ab-demo
	kubectl label ns ab-demo istio-injection=enabled --overwrite
	kubectl apply -f k8s/

delete-ab-demo:
	@echo "Deleting AB Demo..."
	kubectl delete namespace ab-demo
	minikube stop