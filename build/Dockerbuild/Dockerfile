FROM debian:bullseye-backports
WORKDIR /
VOLUME ["/kohaclone", "/kohadebs"]
ENV SUITE="22.11"
ENV PERL5LIB="/kohaclone:/kohaclone/lib"
ENV DEBIAN_FRONTEND="noninteractive"
RUN \
  apt clean ; apt update ; apt upgrade -y ; \
  apt install build-essential file -y ; \
  apt install devscripts pbuilder dh-make fakeroot bash-completion debian-archive-keyring -y ; \
  apt clean ; apt update ; apt upgrade -y
RUN \
  pbuilder clean
COPY base.tgz /var/cache/pbuilder/
RUN \
  apt clean ; apt update ; apt upgrade -y ; \
  apt install curl wget gnupg2 lsb-release -y ; \
  wget -qO - http://debian.koha-community.org/koha/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
  echo deb [signed-by=/usr/share/keyrings/koha.gpg] http://debian.koha-community.org/koha ${SUITE} main $(lsb_release -cs) | tee /etc/apt/sources.list.d/koha.list ; \
  apt clean ; apt update ; apt upgrade -y ; \
  apt install koha-perldeps -y ; \
  apt clean ; apt update ; apt upgrade -y
RUN \
  apt clean ; apt update ; apt upgrade -y ; \
  apt install apt-file libmodern-perl-perl libparallel-forkmanager-perl libsys-cpu-perl libmodule-cpanfile-perl -y ; \
  apt-file update ; \
  apt clean ; apt update ; apt upgrade -y
COPY update.sh /
COPY build.sh /
CMD ["/bin/sh","-c","/build.sh"]
