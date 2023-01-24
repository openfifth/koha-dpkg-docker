#!/bin/bash -x

export SYNC_REPO="${WORKSPACE}/kohaclone"
export DEBS_OUT="${WORKSPACE}/kohadebs"
export KDD_IMAGE="22.11"
export KDD_BRANCH="22.11"
## build kdd
wget -O build.pl https://gitlab.com/ptfs-europe/koha-debs-docker/-/raw/${KDD_BRANCH}/jenkins_config/build.pl
/usr/bin/perl build.pl
