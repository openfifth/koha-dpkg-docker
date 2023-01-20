#!/usr/bin/env bash

/update.sh
cd /kohaclone

export PERL5LIB="/kohaclone:/kohaclone/lib"
export DEB_BUILD_OPTIONS=nocheck
export EMAIL="nobody@localhost.localnet"
export VERSION="$(cat ./Koha.pm | grep "$VERSION = \"" | cut -b 13-20)"

pbuilder --execute --save-after-exec -- /update.sh

./debian/update-control
git checkout -- debian/update-control

./debian/build-git-snapshot -r /kohadebs -v ${VERSION} --noautoversion -d
git checkout -- debian/changelog
