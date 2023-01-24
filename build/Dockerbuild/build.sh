#!/usr/bin/env bash

# source env file
. /.env

## seed update.sh
cat <<EOF | tee /update.sh >/dev/null
#!/bin/sh
    apt clean; apt update
    apt upgrade -y
EOF
chmod +x /update.sh

## cd to workdir, run update.sh
cd /kohaclone
/update.sh

## run update.sh inside pbuilder env
pbuilder --execute --save-after-exec -- /update.sh

## determine version
if [[ -z "${DISTRIBUTION}" ]]; then
	DISTRIBUTION="$(bash -c 'lsb_release -cs')"
fi
if [[ -z "${VERSION}" ]]; then
	VERSION="$(cat ./Koha.pm | grep "VERSION = \"" | cut -b13-20)"
fi

git clean -f

./debian/build-git-snapshot -r /kohadebs -D ${DISTRIBUTION} -g modified -v ${VERSION} --noautoversion -d

git checkout -- debian/control
git checkout -- debian/changelog
