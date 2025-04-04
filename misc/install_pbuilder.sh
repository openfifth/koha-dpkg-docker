#!/usr/bin/env bash

##
##
## check elevation
if [[ "${EUID}" -ne 0 ]]; then
	echo "Please run as root (or sudo)."
	set +x ; exit 1 ; { set +x; } 2>/dev/null
fi


##
##
## script vars
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)" # get current script dir portibly

REAL_USER="$(id -un)" # fallback to root
if [[ ${SUDO_USER} ]]; then
	REAL_USER="${SUDO_USER}" # or use sudo user
fi
REAL_GROUP="$(id -gn ${REAL_USER})" # fallback to real_user group
if [[ ${SUDO_GROUP} ]]; then
	REAL_GROUP="${SUDO_GROUP}" # or use sudo group
fi


##
##
## bienvenido
echo -ne "I: Welcome!\n"
echo -ne "I: Installing pbuilder.\n"
echo -ne "I: From here, you may use the koha-debs-docker Dockerfile\n"
echo -ne "I: For more info, see https://gitlab.com/openfifth/koha-debs-docker/-/wikis/home\n"


##
##
## begin -- install deps
apt clean ; apt update
apt upgrade -y

## install pbuilder
apt install devscripts pbuilder dh-make fakeroot bash-completion debian-archive-keyring -y


##
##
## job done
echo -ne "Done!\n"
exit 0
