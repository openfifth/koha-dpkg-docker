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
/update.sh

## cd to workdir, run update.sh
cd /kohaclone

## run update.sh inside pbuilder env
/usr/sbin/pbuilder --execute --save-after-exec -- /update.sh

## determine version
if [[ -z "${DISTRIBUTION}" ]]; then
	DISTRIBUTION="$(bash -c 'lsb_release -cs')"
fi
if [[ -z "${VERSION}" ]]; then
	VERSION="$(cat ./Koha.pm | grep "VERSION = \"" | cut -b13-20)"
fi

## prep repo
/usr/bin/git clean -f
/usr/bin/git checkout -- .

## begin process
./debian/update-control
/usr/bin/dch --force-distribution -D ${DISTRIBUTION} -v ${VERSION} "Building git snapshot."
/usr/bin/git archive --format=tar --prefix="koha-${VERSION}/" HEAD | gzip -9 > ../koha_${VERSION}.orig.tar.gz
/usr/bin/pdebuild -- --buildresult /kohadebs

## tidy-up
/usr/bin/git checkout -- debian/control
/usr/bin/git checkout -- debian/changelog
