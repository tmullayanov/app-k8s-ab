# App k8s a/b

This is a case-study for canary deployments in k8s/istio setups.


## Toy application

```sh
> cd app
> docker build -t myapp:latest .
```

## Running in minikube

### Tunnel

Tunneling might not lead to exposing ports correctly.
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
Thus, the entry point of our minikube setup is derived from `minikube ip` and mapped port.

## Testing 

VirtualService decides how we split the traffic between versions.
To see (or change the behavior), refer to `k8s/06-virtualservice.yaml`