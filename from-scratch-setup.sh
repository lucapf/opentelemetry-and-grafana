#!/bin/bash

function execute_step(){
  echo  "****** executing step $1"
  $2
  if [ $? -ne 0 ]; then
    echo "!!!!!!!!! step $1 execution FILED! exit" 
    exit -1
  fi
  echo "******* step $1 completed!"
}
function check_cert_manager_installed_and_running(){
  kubectl -n cert-manager wait --for=condition=Available deployment \
         --all --timeout=60s >/dev/null 2>&1 && echo 0 || echo 1
}

function check_opentelemetry_operator_installed_and_running (){
  kubectl -n opentelemetry-operator-system \
          wait --for=condition=Available deployment \
          --all --timeout=60s >/dev/null 2>&1 && echo 0 || echo 1
}

function check_grafana_installed_and_running(){
  # the grafana stack is huge, if we need to download the images it could take a while
  kubectl -n grafana \
          wait --for=condition=Available deployment \
          --all --timeout=500s >/dev/null 2>&1 && echo 0 || echo 1
}

function check_opentelemetry_collector_installed_and_running(){
  kubectl wait --for=condition=Ready pod \
          --all --timeout=60s >/dev/null 2>&1 && echo 0 || echo 1
}

function check_postgresql_installed_and_running(){
  kubectl wait --for=condition=Ready pod \
          --all --timeout=60s >/dev/null 2>&1 && echo 0 || echo 1
}

function execute_step_and_wait(){
  # is idempotent, can be re-applied.
  echo "******* start $1"
  execute_step "$1" "$2"
  if [[ $($3) -eq 1 ]]; then 
      echo "******** timeout!"
      exit -1
  else
    echo "done"
  fi
}

function check_command(){
  command -v $1 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "$1 check passed" 
  else
    echo "$2 check failed, exit"
    exit -1
  fi

}

echo "****** prerequisites"
check_command "docker" "docker installed"
check_command "docker images" "docker not running or not configured with non-root access"
check_command "kind" "kind installed"
check_command "kubectl" "kubectl installed"
check_command "helm" "helm installed"

 
if [ ! "$(kind get clusters)" == "kind" ]; then
execute_step "create cluster" "kind create cluster --config cluster.yaml"
else
  echo "kind cluster already present, skip the step"
fi

if [ -z $(kubectl get namespaces | grep observability-demo) ]; then
  execute_step "create namespace" "kubectl create namespace observability-demo"
else
  echo "namespace observability-demo already present, skip"
fi

execute_step "set namespace" "kubectl config set-context --current --namespace observability-demo"
# if fails  means was already there
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

execute_step_and_wait "cert-manager" \
             "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.2/cert-manager.yaml" \
              "check_cert_manager_installed_and_running"

execute_step_and_wait "open-telemetry-operator" \
            "kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml" \
            "check_opentelemetry_operator_installed_and_running"

# the collector reads the postgres credentials from the "postgres" secret defined here
execute_step_and_wait "postgres" \
              "kubectl apply -f postgresql.yaml" \
              "check_postgresql_installed_and_running"

execute_step_and_wait "otel-collector-daemonset" \
          "kubectl apply  -f otel-collector-daemonset.yaml" \
            "check_opentelemetry_collector_installed_and_running"

execute_step "python-instrumentation" \
            "kubectl apply  -f python-instrumentation.yaml"

cd grafana 
execute_step_and_wait "grafana" \
 "helm install -n grafana --create-namespace --dependency-update --values values.yaml  grafana ." \
  "check_grafana_installed_and_running"
cd ../

cd hello-world-example
echo "build and run the hello world application"
./build-and-push.sh
if [ $? -ne 0 ]; then
    echo "installation failed! pls check the logs"
    exit -1
else 
    echo "installation completed"
fi
cd ../
execute_step "open-ports" "kubectl apply -f services.yaml"

echo "
***********************************************************
************ INSTALLATION COMPLETE! ***********************
***********************************************************

- Grafana dashboard: http://localhost:8000/ (access via **admin/admin**)
- hello world application: http://localhost:8003/docs
example request:

curl -X POST 'http://localhost:8003/urls?url=opentelemetry.io'
"

