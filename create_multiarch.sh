#!/usr/bin/env bash

## vars
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)" # get current script dir portibly

if [[ ${SUDO_USER} ]]; then
	REAL_USER="${SUDO_USER}" # or use sudo user
else
	REAL_USER="$(id -un)" # fallback to root
fi
REAL_GROUP="$(id -gn ${REAL_USER})" # fallback to real_user group

if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
	echo -ne "E: No env file present! Please create one. See the wiki for details\n"
	exit 1
fi

. ${SCRIPT_DIR}/.env
printenv

if [[ "$(docker system info | grep 'io.containerd.snapshotter.v1')" == "" ]]; then
	echo "E: Docker must be set to use containerd-snapshotter. Please see https://docs.docker.com/engine/storage/containerd/#enable-containerd-image-store-on-docker-engine"
	exit 1
fi


##
##
## bienvenido
echo -ne "I: Welcome!\n"
echo -ne "I: This script will merge the amd64 and arm64v8 docker images of your current branch into one, and push it to ghcr.io\n"
echo -ne "I: Please ensure the docker-buildx plugin is correctly installed, and that your system is authenticated with ghcr.io\n"


##
##
## pull the images
if [[ "$(docker image ls | grep ${KDD_REGISTRY} | grep ${KDD_BRANCH}-amd64)" == "" ]]; then
	docker image pull \
	  --platform linux/amd64 \
	  ${KDD_REGISTRY}:${KDD_BRANCH}-amd64
fi
if [[ "$(docker image ls | grep ${KDD_REGISTRY} | grep ${KDD_BRANCH}-arm64v8)" == "" ]]; then
	docker image pull \
	  --platform linux/arm64/v8 \
	  ${KDD_REGISTRY}:${KDD_BRANCH}-arm64v8
fi


##
##
## build the manifest
docker buildx imagetools create -t ${KDD_REGISTRY}:${KDD_BRANCH} \
  ${KDD_REGISTRY}:${KDD_BRANCH}-amd64 \
  ${KDD_REGISTRY}:${KDD_BRANCH}-arm64v8


##
##
## make available locally
docker pull ${KDD_REGISTRY}:${KDD_BRANCH}

echo -ne "I: Remember to delete the old images from your container registry, as they are now clutter\n"
echo -ne "Done!\n"
exit 0
