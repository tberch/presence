export DOCKER_REGISTRY=docker.io
export IMAGE_NAME=tberchenbriter/audio-app-api
export IMAGE_TAG=latest

kubectl patch deployment audio-app-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","image":"'$IMAGE_NAME':'$IMAGE_TAG'"}]}}}}'
kubectl patch deployment audio-app-worker -p '{"spec":{"template":{"spec":{"containers":[{"name":"worker","image":"'$IMAGE_NAME':'$IMAGE_TAG'"}]}}}}'
