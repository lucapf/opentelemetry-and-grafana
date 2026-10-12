#!/bin/bash
IMAGE="hello-world:0.0.2"

echo -n "loading image to kind.."
docker build -t $IMAGE .

if [ $? -ne 0 ]; then
  echo ".. FAILED pls check the logs"
  exit -1
else
  echo ".. SUCCESS!"
fi

echo -n "loading image to kind.."
kind load docker-image $IMAGE
if [ $? -ne 0 ]; then
  echo ".. FAILED cannot load the image, pls check the logs"
  exit -2
else
  echo ".. SUCCESS!"
fi

echo -n "deploy postgres.."
kubectl apply -f postgresql.yaml
if [ $? -ne 0 ]; then
  echo ".. FAILED cannot deploy postgres, pls check the logs"
  exit -3
else
  echo ".. SUCCESS!"
fi

echo -n "deploy image.."
kubectl apply -f hello-wold-deployment.yaml
if [ $? -ne 0 ]; then
  echo ".. FAILED cannot deploy the hello-world image, pls check the logs"
  exit -4
else
  echo ".. SUCCESS!"
fi

echo "
*****
hello world configuration completed. To access the pod pls use the port forwarding command:

kubectl port-forward <pod-id> 8000:8000

then access to the api at the address http://localhost:8000/docs

To delete the instance:

kubectl delete deploymet hello-world-example
*****
"
