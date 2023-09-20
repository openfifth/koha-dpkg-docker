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
if [[ ! -f "${SCRIPT_DIR}/build.env" ]]; then
	echo -ne "E: No env file present! Please create one. See the wiki for details\n"
	exit 1
else
	. ${SCRIPT_DIR}/.env
fi


##
##
## bienvenido
echo -ne "I: Welcome!\n"
echo -ne "I: This script will generate a base.tgz using pbuilder, and from there generate a docker image from the Dockerfile.\n"
echo -ne "I: Please ensure docker and pbuilder are properly installed, and your .env is correctly configured, before continuing.\n"


##
##
## check keyring is present
if [[ ! -f "${KEYRING}" ]]; then
	echo -ne "E: ${KEYRING} is missing. Please install it!\n"
	exit 1
fi


##
##
## start pbuilder stuff -- create base
pbuilder --debug clean
rm -vf /var/cache/pbuilder/base.tgz
pbuilder --debug create --distribution "${DISTRIBUTION}" --mirror "${MIRROR}/" --debootstrapopts "--components=main" --debootstrapopts "--keyring=${KEYRING}"

## seed and execute additional deps
cat <<EOT | tee /tmp/koha_pbuilder.sh
#!/usr/bin/env bash
    apt clean; apt update ; apt upgrade -y ; \
    apt install curl wget ca-certificates gnupg2 -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo 'deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main' | tee /etc/apt/sources.list.d/koha.list ; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
    echo 'deb [signed-by=/usr/share/keyrings/nodesource.gpg] http://deb.nodesource.com/node_14.x/ ${DISTRIBUTION} main' | tee /etc/apt/sources.list.d/nodesource.list ; \
    wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn.gpg >/dev/null ; \
    echo 'deb [signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/debian/ stable main' | tee /etc/apt/sources.list.d/yarn.list ; \
    apt clean ; apt update ; \
    apt install koha-perldeps docbook-xsl-ns apt-file -y ; \
    apt clean ; apt update ; \
    apt-file update ; \
EOT
chmod -v +x /tmp/koha_pbuilder.sh

## run seeded file
pbuilder --execute --save-after-exec -- /tmp/koha_pbuilder.sh
mv -v /var/cache/pbuilder/base.tgz /tmp/koha_base.tgz
rm -f /tmp/koha_pbuilder.sh


##
##
## start dockerfile stuff -- create base
cat <<EOT | tee /tmp/koha_build.sh
#!/usr/bin/env bash

# source env file
. /.env

## update now
apt clean; apt update
apt upgrade -y

## cd to workdir, run update.sh
cd /kohaclone

## run update.sh inside pbuilder env
cat <<EOF | tee /tmp/apt_upgrade.sh
  apt clean ; apt update
  apt upgrade -y
EOF
chmod -v +x /tmp/apt_upgrade.sh
/usr/sbin/pbuilder --execute --save-after-exec -- /tmp/apt_upgrade.sh

## determine version
if [[ -z "${DISTRIBUTION}" ]]; then
	DISTRIBUTION="$(bash -c 'lsb_release -cs')"
fi
if [[ -z "${VERSION}" ]]; then
	VERSION="$(cat ./Koha.pm | grep "VERSION = \"" | cut -b13-20)"
fi
if [[ -z "${REV}" ]]; then
	REV="$(date +%s)"
fi

## prep repo
/usr/bin/git clean -f
/usr/bin/git checkout -- .

## prep control
./debian/update-control
/usr/bin/git add debian/control
/usr/bin/git commit --no-verify -m "LOCAL: Updated debian/control file: ${VERSION}-${REV}"

## prep css / js
/usr/bin/perl build-resources.PL
/usr/bin/git add koha-tmpl/\* -f
/usr/bin/git commit --no-verify -m "LOCAL: Updated js / css: ${VERSION}-${REV}"

## build dpkg
/usr/bin/dch --force-distribution -D "${DISTRIBUTION}" -v "${VERSION}-${REV}" "Building git snapshot."
/usr/bin/dch -r "Building git snapshot."
/usr/bin/git archive --format="tar" --prefix="koha-${VERSION}/" HEAD | gzip > ../koha_${VERSION}.orig.tar.gz
/usr/bin/pdebuild -- --basetgz "/var/cache/pbuilder/base.tgz" --buildresult "/kohadebs"

## tidy-up
/usr/bin/git clean -f
/usr/bin/git checkout -- .

exit 0
EOT
chmod -v +x /tmp/koha_build.sh

## prepare Dockerfile
cp -v ${SCRIPT_DIR}/.env /tmp/koha.env
cat <<EOT | tee /tmp/koha_Dockerfile
FROM debian:bookworm
WORKDIR /
VOLUME ["/kohaclone", "/kohadebs"]
COPY /tmp/koha.env /.env
RUN \
    . /.env ; \
    echo 'deb http://deb.debian.org/debian bookworm-backports main' > /etc/apt/sources.list.d/backports.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install curl wget gnupg2 ca-certificates -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main | tee /etc/apt/sources.list.d/koha.list ; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/nodesource.gpg] http://deb.nodesource.com/node_14.x/ bookworm main | tee /etc/apt/sources.list.d/nodesource.list ; \
    wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/debian/ stable main | tee /etc/apt/sources.list.d/yarn.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install build-essential git file -y ; \
    apt install devscripts pbuilder dh-make fakeroot bash-completion apt-file debian-archive-keyring -y ; \
    apt install nodejs yarn -y ; \
    apt install libmodern-perl-perl libmodule-cpanfile-perl libparallel-forkmanager-perl libsys-cpu-perl -y ; \
    git config --global --add safe.directory /kohaclone ; \
    npm set strict-ssl false -g ; \
    npm install -g gulp-cli@latest ; \
    yarn config set strict-ssl false -g ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt-file update ; \
    pbuilder --debug clean ; \
COPY /tmp/koha_base.tgz /var/cache/pbuilder/
COPY /tmp/build.sh /
CMD ["/bin/sh","-c","/build.sh"]
EOT


##
##
## job done
echo -ne "Done!\n"
exit 0
