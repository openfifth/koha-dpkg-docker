FROM debian:bullseye
WORKDIR /
VOLUME ["/kohaclone", "/kohadebs"]
COPY docker.env /.env
RUN \
    . /.env ; \
    echo "deb http://deb.debian.org/debian bullseye-backports main" > /etc/apt/sources.list.d/backports.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install build-essential git file -y ; \
    git config --global --add safe.directory /kohaclone ; \
    apt install devscripts pbuilder dh-make fakeroot bash-completion debian-archive-keyring -y ; \
    apt install apt-file libmodern-perl-perl libparallel-forkmanager-perl libsys-cpu-perl libmodule-cpanfile-perl -y ; \
    apt install curl wget gnupg2 lsb-release -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main | tee /etc/apt/sources.list.d/koha.list ; \
    apt clean ; apt update ; \
    apt-file update ; \
    pbuilder clean
COPY base.tgz /var/cache/pbuilder/
COPY build.sh /
CMD ["/bin/sh","-c","/build.sh"]
