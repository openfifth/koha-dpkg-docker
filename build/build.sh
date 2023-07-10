#!/usr/bin/env bash
set -x

# source env file
. /.env

## seed update.sh
cat <<EOF | tee /tmp/update.sh >/dev/null
#!/bin/sh
    apt clean; apt update
    apt upgrade -y
EOF
chmod +x /tmp/update.sh
/tmp/update.sh

## cd to workdir, run update.sh
cd /kohaclone

## run update.sh inside pbuilder env
/usr/sbin/pbuilder --execute --save-after-exec -- /tmp/update.sh

## determine version
if [[ -z "${DISTRIBUTION}" ]]; then
	DISTRIBUTION="$(bash -c 'lsb_release -cs')"
fi
if [[ -z "${VERSION}" ]]; then
	VERSION="$(cat ./Koha.pm | grep "VERSION = \"" | cut -b13-20)"
fi
if [[ -z "${REV}" ]]; then
	REV="$(git rev-list --count HEAD)"
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

set +x
exit 0
