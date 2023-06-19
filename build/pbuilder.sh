#!/usr/bin/env bash
set -x

## vars
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)" # get current script dir portibly
if [[ ${SUDO_USER} ]]; then
	REAL_USER="${SUDO_USER}" # or use sudo user
else
	REAL_USER="$(id -un)" # fallback to root
fi
REAL_GROUP="$(id -gn ${REAL_USER})" # fallback to real_user group
if [[ ! -f "${SCRIPT_DIR}/build.env" ]]; then
	echo -ne "! No env file present! Please create one. See the wiki for details\n"
	exit 1
else
	. ${SCRIPT_DIR}/build.env
fi


##
##
## bienvenido
echo -ne "Welcome!\nInstalling pbuilder and providing a base.tgz file to this directory.\nFrom here, you may use the koha-debs-docker Dockerfile\nFor more info, see https://gitlab.com/ptfs-europe/koha-debs-docker/-/wikis/home\n"


##
##
## check keyring is present
if [[ ! -f "${KEYRING}" ]]; then
	echo -ne "! ${KEYRING} is missing. Please install it!\n"
	exit 1
fi


##
##
## start pbuilder stuff -- create base
pbuilder clean
rm -f /var/cache/pbuilder/base.tgz

## if there is a valid unsoiled file, keep it
if [[ -z "$(find /var/cache/pbuilder/base_unsoiled_${DISTRIBUTION}.tgz -mtime -1 -print)" ]]; then
	rm -f /var/cache/pbuilder/base_unsoiled_${DISTRIBUTION}.tgz
	pbuilder create --distribution "${DISTRIBUTION}" --mirror "${MIRROR}/" --debootstrapopts "--components=main" --debootstrapopts "--keyring=${KEYRING}"
	cp /var/cache/pbuilder/base.tgz /var/cache/pbuilder/base_unsoiled_${DISTRIBUTION}.tgz
else
	cp /var/cache/pbuilder/base_unsoiled_${DISTRIBUTION}.tgz /var/cache/pbuilder/base.tgz
fi

## seed and execute additional deps
cat <<EOF | tee /tmp/koha_pbuilder.sh >/dev/null
#!/usr/bin/env bash
    set -x ; \
    apt clean; apt update ; apt upgrade -y ; \
    apt install curl wget ca-certificates gnupg2 -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main | tee /etc/apt/sources.list.d/koha.list ; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/nodesource.gpg] http://deb.nodesource.com/node_14.x/ bookworm main | tee /etc/apt/sources.list.d/nodesource.list ; \
    wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/debian/ stable main | tee /etc/apt/sources.list.d/yarn.list ; \
    apt clean ; apt update ; \
    apt install koha-perldeps docbook-xsl-ns apt-file -y ; \
    apt clean ; apt update ; \
    apt-file update ; \
    set +x
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
