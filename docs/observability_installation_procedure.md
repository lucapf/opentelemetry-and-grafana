# Installation procedure

Main resource:
**[opentelmetry kubernetes getting started page](https://opentelemetry.io/docs/platforms/kubernetes/getting-started/)**


## Prerequisites

- `kind`
- `helm`
- internet connection

Below the installation procedure

## Create kind cluster

Using the command 

```
kind create cluster --config cluster.yaml

```
the content of the `cluster.yaml` is in the same directory as the example.

Create the observability namespace and set it as default to us for the rest of the procedure:

```
kubectl create namespace observability-demo
kubectl config set-context --current --namespace observability-demo
```

Now let's add the `opentelemetry-helm-charts` to our helm repository.

```
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
```

## Open telemetry operator

The Open Telemetry operator requires a cert manager to be installed in the cluster

### install cert manager

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.2/cert-manager.yaml
```


Verify the installation went well:

- the `cert-manager` namespace exists. `kubectl get namespaces`
- the cert manager pods are running `kubect -n cert-manager get pods` should return 3 running pods

### Install the Open-telemetry operator

```
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

Verify the installation: `kubectl -n opentelemetry-operator-system get pods`

## Install OtelCollector

We are using the operator to install the OtelCollector in *DaemonSet* mode.

_A DaemonSet is a special type of pod that run an instance per node and can access to the node filesystem._

Using this approach we are able to use the same instance to collect metrics coming from the node logs and metrics from the virtual/physical machine and coming from Kubernetes components like the `kubelet`. 

```
kubectl apply -f otel-collector-daemonset.yaml
```

Verify that everything works as expected `kubectl get pods`

The open telemetry operator requires `cert-manager` to be installed

### Create the custom application to trace

#### build and push the hello-world-example application to the cluster

`hello-world-example` directory execute the `build-and-push.sh` script to build the hello world image and push it in the kind default cluster.


## Auto instrumentation of the code

The auto instrumentation of the code is using the configuration of the  `instrumentation` kind provided by the `opentelemetry` system and execute auto instrumentation of the code managed by the system.


### create the instrumentation deployment

```
kubectl apply -f python-instrumentation.yaml
```



## Install Grafana observability stack

- Go to the `grafana` folder
- install the chart
  ```
  helm install -n grafana  --create-namespace --dependency-update --values values.yaml  grafana .
  ```
- bind the port
  ```
  kubectl port-forward -n grafana svc/grafana 3000:80
  ```
  ```
  ```


## The Hello World application

The hello world application uses a standard python stack to expose a simple api.

The hello world application code does not contains any reference to the instrumentation.
The only changed required is in the `startup script` that run the instrumentation generic command:
```

CMD ["/bin/bash", "-c", "opentelemetry-instrument fastapi run /hello-world/app/main.py"]
```
