#!/usr/bin/env bash

##
##
## check elevation
if [[ "${EUID}" -ne 0 ]]; then
	echo "Please run as root (or sudo)."
	exit 1
fi


##
##
## script vars
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)" # get current script dir portibly

REAL_USER="$(id -un)" # fallback to root
if [[ ${SUDO_USER} ]]; then
	REAL_USER="${SUDO_USER}" # or use sudo user
fi
REAL_GROUP="$(id -gn ${REAL_USER})" # fallback to real_user group
if [[ ${SUDO_GROUP} ]]; then
	REAL_GROUP="${SUDO_GROUP}" # or use sudo group
fi
DPKG_ARCH=""
LSB_ID=""
LSB_CODENAME=""


##
##
## bienvenido
echo -ne "I: Welcome!\n"
echo -ne "I: Installing Docker and adding current user to docker group.\n"
echo -ne "I: From here, you may use the koha-debs-docker Dockerfile\n"
echo -ne "I: For more info, see https://gitlab.com/ptfs-europe/koha-debs-docker/-/wikis/home\n"


##
##
## begin -- install deps
apt clean ; apt update
apt upgrade -y

## install base tools
apt install ca-certificates curl gnupg lsb-release -y


##
##
## set some vars
DPKG_ARCH="$(dpkg --print-architecture)"
LSB_ID="$(bash -c 'lsb_release -is | tr [:upper:] [:lower:]')"
LSB_CODENAME="$(bash -c 'lsb_release -cs | tr [:upper:] [:lower:]')"


##
##
## add key to keychain & repo to apt lists
mkdir -vp /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/${LSB_ID}/gpg | gpg --dearmor | tee /usr/share/keyrings/docker.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/${LSB_ID} ${LSB_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list


##
##
## install docker
apt clean ; apt update
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
apt install docker-compose -y

## enable and run dockerd
systemctl enable --now docker.service
systemctl start docker.service

## add current user to docker group
usermod -aG docker ${REAL_USER}


##
##
## test docker for validity
docker run hello-world


##
##
## job done
echo -ne "Done!\n"
exit 0
