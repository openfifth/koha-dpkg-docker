#!/usr/bin/env bash
set -x

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
if [[ ! -f "${SCRIPT_DIR}/pbuilder.env" ]]; then
	echo -ne "! No env file present! Please create one. See the wiki for details\n"
	exit 1
fi
. ${SCRIPT_DIR}/pbuilder.env


##
##
## bienvenido
echo -ne "Welcome!\nInstalling pbuilder and providing a base.tgz file to this directory.\nFrom here, you may use the koha-debs-docker Dockerfile\nFor more info, see https://gitlab.com/ptfs-europe/koha-debs-docker/-/wikis/home\n"


##
##
## begin -- install deps
rm -f /var/cache/pbuilder/bash.tgz
apt clean ; apt update
apt upgrade -y

## install pbuilder
apt install devscripts pbuilder dh-make fakeroot bash-completion debian-archive-keyring -y

## install debian archive keyring
apt install debian-archive-keyring -y
if [[ ! -f "${KEYRING}" ]]; then
	echo -ne "! ${KEYRING} is missing. Please install it!\n"
	exit 1
fi

##
##
## start pbuilder stuff -- create base
pbuilder clean
pbuilder create --distribution ${DISTRIBUTION} --mirror ${MIRROR}/ --debootstrapopts "--components=main" --debootstrapopts "--keyring=${KEYRING}"

## seed and execute additional deps
cat <<EOF | tee /tmp/koha_pbuilder.sh >/dev/null
#!/usr/bin/env bash
    apt clean; apt update ; apt upgrade -y ; \
    apt install wget gnupg2 -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main | tee /etc/apt/sources.list.d/koha.list >/dev/null ; \
    apt clean ; apt update ; \
    apt install apt-file koha-perldeps -y ; \
    apt-file update ; \
    apt clean ; apt update
EOF
chmod +x /tmp/koha_pbuilder.sh

## run seeded file
pbuilder --execute --save-after-exec -- /tmp/koha_pbuilder.sh
rm -f /tmp/koha_pbuilder.sh


##
##
## mv base.tgz
mv /var/cache/pbuilder/base.tgz ${SCRIPT_DIR}/
chown ${REAL_USER}:${REAL_GROUP} ${SCRIPT_DIR}/base.tgz


##
##
## job done
ls -lh ${SCRIPT_DIR}
echo -ne "Done!\n"
set +x
exit 0
