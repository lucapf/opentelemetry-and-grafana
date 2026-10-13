# Installation procedure

Main resource:
[OpenTelemetry k8s getting started page](https://opentelemetry.io/docs/platforms/kubernetes/getting-started/)
## Prerequisites

- `docker` configured with non-root access (Linux)
- `kind`
- `helm`
- `kubectl`
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

- the `cert-manager` namespace exists: `kubectl get namespaces`
- the cert manager pods are running: `kubectl -n cert-manager get pods` should return 3 running pods

### Install the Open-telemetry operator

```
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

Verify the installation: `kubectl -n opentelemetry-operator-system get pods`

## Install OtelCollector

We are using the operator to install the OtelCollector in *DaemonSet* mode.

_A DaemonSet is a special type of pod that run an instance per node and can access to the node file-system._

Using this approach we are able to use the same instance to collect metrics coming from the node logs and metrics from the virtual/physical machine and coming from Kubernetes components like the `kubelet`.

```
kubectl apply -f otel-collector-daemonset.yaml
```

Verify that everything works as expected `kubectl get pods`

The open telemetry operator requires `cert-manager` to be installed


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
  helm install -n grafana  --create-namespace --dependency-update --values values.yaml  grafana
  ```
  
## Install the database

Deploy the database via:

```
kubectl apply -f postgresq.yaml
```

The script also initialize the hello-world database.

## The Hello World application

The hello world application is a small **URL store** built with FastAPI and PostgreSQL.

### Application files:
- `main.py` :  http endpoint
- `license.py`: license check
- `storage.py`: storage (PostgreSQL) access

### API

- `POST /urls` receives `{"url": "..."}`, validates it, stores it in PostgreSQL and replies
  `200 {"message": "your request has been stored!", "id": N}`.

### License

 Te application can only store 10 new URLS because the licensing model. 
If no more licenses are available the system respond with 
  `403 license expired`.
The counter is reset after each reboot

### Logging

The logging convention (fixed event message, details in `extra={...}`).
See the [logging doc](./logging.md) for further detail.

### Other errors 
An unreachable database gets `503`.

### OpenTelemetry integration

The application code does not contain any telemetry setup: the OpenTelemetry operator injects the Python agent, which traces the FastAPI requests, propagate to the database calls and exports the logs.

By default the operator doesn't trace internal function calls. 
Usually business steps are traced. Is still possible to add custom traces via annotation as shown in `validate_license`.


#### How the application is instrumented

The startup script runs the generic instrumentation (opentelemetry-instrument) command:

```
CMD ["/bin/bash", "-c", "opentelemetry-instrument fastapi run /hello-world/app/main.py"]
```

While the new Kubernetes kind `Instrumentation` manages the instrumentation configuration.

## build and deploy the hello-world-example application and its database

- Go into the `hello-world-example` directory
- Execute `build-and-push.sh`. The script:
  - builds the image and loads it into the kind cluster
  - deploys the application (`hello-wold-deployment.yaml`)

### try it

```sh
curl -X POST "localhost:8003/urls?url=opentelemetry.io/docs"
# {"message":"your request has been stored!","id":1}
# after 10 requests:
# {"detail":"license expired"}   (HTTP 403)
```

## Enable the access

- move back to the project root directory
- apply the `services.yaml` file
  ```
  kubectl apply -f services.yaml
  ```

## Access URL

- Grafana dashboard: `http://localhost:8000/` (access via **admin/admin**)
- Hello World application: `http://localhost:8003/docs`
- Prometheus metrics: `http://localhost:8002/metrics`
- Loki logs: `http://localhost:8001/loki/api/v1/tail`

## Access mapping port
The table below show the static configuration.

| application | internal port | nodePort | external port |
|-------------|---------------|----------|---------------|
| Hello World | 8000          | 3083     | 8003          |
| Prometheus  | 80            | 3082     | 8002          |
| Loki        | 80            | 3081     | 8001          |
| Grafana     | 80            | 3080     | 8000          |
