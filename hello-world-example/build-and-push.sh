#!/bin/bash
IMAGE="hello-world:0.0.2"

echo -n "building the app.."
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
hello world configuration completed. 

To delete the instance:

kubectl delete deploymet hello-world-example
*****
"
