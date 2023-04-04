FROM debian:bullseye
WORKDIR /
VOLUME ["/kohaclone", "/kohadebs"]
COPY build.env /.env
RUN \
    set -x ; \
    . /.env ; \
    echo "deb http://deb.debian.org/debian bullseye-backports main" > /etc/apt/sources.list.d/backports.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install curl wget gnupg2 ca-certificates -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main | tee /etc/apt/sources.list.d/koha.list ; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/nodesource.gpg] http://deb.nodesource.com/node_14.x/ bullseye main | tee /etc/apt/sources.list.d/nodesource.list ; \
    wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/debian/ stable main | tee /etc/apt/sources.list.d/yarn.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install build-essential git file -y ; \
    apt install devscripts pbuilder dh-make fakeroot bash-completion apt-file debian-archive-keyring -y ; \
    apt install nodejs yarn -y ; \
    apt install libmodern-perl-perl libmodule-cpanfile-perl libparallel-forkmanager-perl libsys-cpu-perl -y ; \
    git config --global --add safe.directory /kohaclone ; \
    npm set strict-ssl false -g ; \
    npm install -g gulp-cli@latest ; \
    yarn config set strict-ssl false -g ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt-file update ; \
    pbuilder clean ; \
    set +x
COPY base.tgz /var/cache/pbuilder/
COPY build.sh /
CMD ["/bin/sh","-c","/build.sh"]
