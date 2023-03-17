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

## prep repo
/usr/bin/git clean -f
/usr/bin/git checkout -- .

## prep control
./debian/update-control
/usr/bin/git add debian/control
/usr/bin/git commit -m "LOCAL: Updated debian/control file: ${VERSION}-1"

## build dry-run
PERL_MM_USE_DEFAULT=1 /usr/bin/perl Makefile.PL
make ; rm -rf ./blib
/usr/bin/git add koha-tmpl/\*.css -f
/usr/bin/git add koha-tmpl/\*.css -f
/usr/bin/git add koha-tmpl/\*LICENSE* -f
/usr/bin/git commit -m "LOCAL: Updated js / css: ${VERSION}-1"

## build dpkg
/usr/bin/dch --force-distribution -D "${DISTRIBUTION}" -v "${VERSION}-1" "Building git snapshot."
/usr/bin/dch -r "Building git snapshot."
/usr/bin/git archive --format="tar" --prefix="koha-${VERSION}/" HEAD | gzip > ../koha_${VERSION}.orig.tar.gz
/usr/bin/pdebuild -- --basetgz "/var/cache/pbuilder/base.tgz" --buildresult "/kohadebs"

## tidy-up
/usr/bin/git clean -f
/usr/bin/git checkout -- .

set +x
exit 0
