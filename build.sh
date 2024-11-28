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
else
	. ${SCRIPT_DIR}/.env
	printenv
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
## prep env
echo -ne "I: Copying .env file to temp\n"
mkdir -vp /tmp/koha-dpkg-docker
cd /tmp/koha-dpkg-docker
cp -v ${SCRIPT_DIR}/.env /tmp/koha-dpkg-docker/.env


##
##
## start pbuilder stuff -- create base
echo -ne "I: Cleaning pbuilder\n"
pbuilder clean
rm -vf /var/cache/pbuilder/base.tgz
echo -ne "I: Creating blank image\n"
pbuilder create --distribution "${DISTRIBUTION}" --mirror "${MIRROR}/" --debootstrapopts "--components=main" --debootstrapopts "--keyring=${KEYRING}"

## seed and execute additional deps
echo -ne "I: Seeing apt control script\n"
cat <<EOF | tee /tmp/koha-dpkg-docker/apt_control.sh
#!/usr/bin/env bash
  echo "" > /etc/apt/sources.list ; \
  echo "deb ${MIRROR} ${DISTRIBUTION} main contrib non-free" > /etc/apt/sources.list.d/${FAMILY}.list ; \
  echo "deb ${MIRROR} ${DISTRIBUTION}-updates main contrib non-free" >> /etc/apt/sources.list.d/${FAMILY}.list ; \
  echo "deb ${MIRROR_SEC} ${DISTRIBUTION_SEC} main contrib non-free" >> /etc/apt/sources.list.d/${FAMILY_SEC}.list ; \
  echo "deb ${MIRROR} ${DISTRIBUTION}-backports main contrib non-free" > /etc/apt/sources.list.d/backports.list ; \
  apt clean ; apt update ; apt upgrade -y ; apt dist-upgrade -y \ ;
  apt install apt-file -y ; \
  apt clean ; apt update ; \
  apt-file update
EOF
chmod -v 0755 /tmp/koha-dpkg-docker/apt_control.sh

echo -ne "I: Seeding pbuilder script\n"
cat <<EOF | tee /tmp/koha-dpkg-docker/pbuilder_control.sh
#!/usr/bin/env bash
  apt clean ; apt update ; \
  apt install curl wget ca-certificates gnupg2 -y ; \
  wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
  echo "deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main" | tee /etc/apt/sources.list.d/koha.list ; \
  wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] http://deb.nodesource.com/node_18.x/ ${DISTRIBUTION} main" | tee /etc/apt/sources.list.d/nodesource.list ; \
  wget -qO - https://dl.yarnpkg.com/${FAMILY}/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn.gpg >/dev/null ; \
  echo "deb [signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/${FAMILY}/ stable main" | tee /etc/apt/sources.list.d/yarn.list ; \
  apt clean ; apt update ; \
  apt install koha-perldeps docbook-xsl-ns -y
EOF
chmod -v 0755 /tmp/koha-dpkg-docker/pbuilder_control.sh

## run seeded file
echo -ne "I: Running apt_control seed script atop pbuilder\n"
pbuilder --execute --save-after-exec -- /tmp/koha-dpkg-docker/apt_control.sh
echo -ne "I: Running pbuilder_control seed script atop pbuilder\n"
pbuilder --execute --save-after-exec -- /tmp/koha-dpkg-docker/pbuilder_control.sh
mv -v /var/cache/pbuilder/base.tgz /tmp/koha-dpkg-docker/base.tgz


##
##
## start dockerfile stuff -- create base
echo -ne "I: Seeding build.sh for Docker image\n"
cat <<EOF | tee /tmp/koha-dpkg-docker/build.sh
#!/usr/bin/env bash

# source env file
. /.env

## update now
apt clean; apt update
apt upgrade -y

## cd to workdir, run update.sh
cd /kohaclone

## run update.sh inside pbuilder env
echo -ne '#!/usr/bin/env bash\\n\\napt clean ; apt update\napt upgrade -y\n' | tee /tmp/apt_upgrade.sh
chmod -v 0755 /tmp/apt_upgrade.sh
/usr/sbin/pbuilder --execute --save-after-exec -- /tmp/apt_upgrade.sh

## determine version
if [[ -z "\${DISTRIBUTION}" ]]; then
	DISTRIBUTION="\$(bash -c 'lsb_release -cs')"
fi
if [[ -z "\${VERSION}" ]]; then
	VERSION="\$(cat ./Koha.pm | grep "VERSION = \"" | cut -b13-20)"
fi
if [[ -z "\${REV}" ]]; then
	REV="\$(date +%s)"
fi

## prep repo
/usr/bin/git clean -f
/usr/bin/git checkout -- .

## prep env
export PERL5LIB="/kohaclone:/kohaclone/lib"
export KOHA_CONF=""
export KOHA_HOME="/kohaclone"

## prep git
git config --global user.email "root@localhost.localnet"
git config --global user.name  "root"

## prep control
./debian/update-control
/usr/bin/git add debian/control
/usr/bin/git commit --no-verify -m "LOCAL: Updated debian/control file: \${VERSION}-\${REV}"

## prep css / js
/usr/bin/perl build-resources.PL
/usr/bin/git add koha-tmpl/\\* -f
/usr/bin/git add api\\/* -f
/usr/bin/git commit --no-verify -m "LOCAL: Updated js / css: \${VERSION}-\${REV}"

## build dpkg
/usr/bin/dch --force-distribution -D "\${DISTRIBUTION}" -v "\${VERSION}-\${REV}" "Building git snapshot."
/usr/bin/dch -r "Building git snapshot."
/usr/bin/git archive --format="tar" --prefix="koha-\${VERSION}/" HEAD | gzip > ../koha_\${VERSION}.orig.tar.gz
/usr/bin/pdebuild -- --basetgz "/var/cache/pbuilder/base.tgz" --buildresult "/kohadebs"

## tidy-up
/usr/bin/git clean -f
/usr/bin/git checkout -- .

exit 0
EOF
chmod -v 0755 /tmp/koha-dpkg-docker/build.sh

## prepare Dockerfile
echo -ne "I: Seeding Dockerfile for image construction\n"
cat <<EOF | tee /tmp/koha-dpkg-docker/Dockerfile
FROM ${FAMILY}:${DISTRIBUTION}
WORKDIR /
VOLUME ["/kohaclone", "/kohadebs"]
COPY .env /.env
RUN \
    . /.env ; \
    echo "deb ${MIRROR} ${DISTRIBUTION}-backports main" > /etc/apt/sources.list.d/backports.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install curl wget gnupg2 ca-certificates -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo "deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main" | tee /etc/apt/sources.list.d/koha.list ; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] http://deb.nodesource.com/node_14.x/ bookworm main" | tee /etc/apt/sources.list.d/nodesource.list ; \
    wget -qO - https://dl.yarnpkg.com/${FAMILY}/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn.gpg >/dev/null ; \
    echo "deb [signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/${FAMILY}/ stable main" | tee /etc/apt/sources.list.d/yarn.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install build-essential git file -y ; \
    apt install devscripts pbuilder dh-make fakeroot bash-completion apt-file ${FAMILY}-archive-keyring -y ; \
    apt install nodejs yarn -y ; \
    apt install libmodern-perl-perl libmodule-cpanfile-perl libparallel-forkmanager-perl libsys-cpu-perl -y ; \
    git config --global --add safe.directory /kohaclone ; \
    npm set strict-ssl false -g ; \
    npm install -g gulp-cli@latest ; \
    yarn config set strict-ssl false -g ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt-file update ; \
    pbuilder clean
COPY base.tgz /var/cache/pbuilder/
COPY build.sh /
CMD ["/bin/sh","-c","/build.sh"]
EOF


##
##
## job run
cd /tmp/koha-dpkg-docker/
echo -ne "I: Building Docker image for k.d.d building"
cat Dockerfile | docker build -t ${KDD_REGISTRY}:${KDD_BRANCH} -f - .

##
##
## job done
echo -ne "I: Removing disused temp files\n"
rm -vf /tmp/koha-dpkg-docker/.env
rm -vf /tmp/koha-dpkg-docker/base.tgz
rm -vf /tmp/koha-dpkg-docker/apt_control.sh
rm -vf /tmp/koha-dpkg-docker/pbuilder_control.sh
rm -vf /tmp/koha-dpkg-docker/build.sh
rm -vf /tmp/koha-dpkg-docker/Dockerfile
rm -vrf /tmp/koha-dpkg-docker/
echo -ne "Done!\n"
exit 0
