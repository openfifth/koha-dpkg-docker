#!/bin/bash -x

## cd to kohaclone
cd ${WORKSPACE}/kohaclone

export SYNC_REPO="${WORKSPACE}/kohaclone"
export DEBS_OUT="${WORKSPACE}/kohadebs"
export KDD_IMAGE="master"
export KDD_BRANCH="master"
## build kdd
wget -O build.pl https://gitlab.com/ptfs-europe/koha-debs-docker/-/raw/${KDD_BRANCH}/jenkins_config/build.pl
/usr/bin/perl build.pl
