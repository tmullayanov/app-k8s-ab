# App k8s a/b

This is a case-study for canary deployments in k8s/istio setups.


## Toy application

```sh
> cd app
> docker build -t myapp:latest .
```

## Running in minikube

```sh
# Run minikube + istio. Make sure minikube, istioctl, kubectl are installed
minikube start --cpus=4 --memory=8192
istioctl install --profile=demo -y
kubectl create ns ab-demo
kubectl label ns ab-demo istio-injection=enabled --overwrite

kubectl apply -f k8s/

# IN SEPARATE TERMINAL
# to expose ingress to your host.
minikube tunnel
```


### Tunnel

```sh
# in separate terminal
> minikube tunnel
```

The output of this command (do not interrupt it!) is supposed to show the exposed port accessible via 127.0.0.1. Though, sometimes tunneling might not lead to exposing ports correctly.
To alleviate that, use the following:

```sh
> minikube ip
10.10.10.10  # just an example
```

This is the address we should make our requests at.

```sh
> kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.109.212.78   10.109.212.78   15021:31538/TCP,80:31962/TCP,443:30715/TCP,31400:31990/TCP,15443:31540/TCP   81m

```

Here, we see that port `80` was mapped to `31962`.
`80` port is set to be entry-point to our ingress, as it is defined in `k8s/05-gateway.yaml`.
Thus, the entry point of our minikube setup is derived from `minikube ip` and mapped port.

## Testing 

VirtualService decides how we split the traffic between versions.
To see (or change the behavior), refer to `k8s/06-virtualservice.yaml`

Examples of requests (change the IP:PORT of your minikube accordingly)

```sh
> curl -H "Host: myapp.local" -H "x-role: beta_tester" http://192.168.49.2:31962
```

```sh
> curl -H "Host: myapp.local" http://192.168.49.2:31962
```