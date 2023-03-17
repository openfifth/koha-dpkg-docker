FROM debian:bullseye
WORKDIR /
VOLUME ["/kohaclone", "/kohadebs"]
COPY build.env /.env
RUN \
    . /.env ; \
    echo "deb http://deb.debian.org/debian bullseye-backports main" > /etc/apt/sources.list.d/backports.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install curl wget gnupg2 ca-certificates -y ; \
    wget -qO - ${REPO}/gpg.asc | gpg --dearmor | tee /usr/share/keyrings/koha.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/koha.gpg] ${REPO}/ ${SUITE} main | tee /etc/apt/sources.list.d/koha.list ; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null ; \
    echo deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x/ bullseye main | tee /etc/apt/sources.list.d/nodesource.list ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt install build-essential git file -y ; \
    apt install devscripts pbuilder dh-make fakeroot bash-completion apt-file debian-archive-keyring -y ; \
    apt install nodejs -y ; \
    apt install libmodern-perl-perl libmodule-cpanfile-perl libparallel-forkmanager-perl libsys-cpu-perl -y ; \
    git config --global --add safe.directory /kohaclone ; \
    npm set strict-ssl false -g ; \
    npm install -g corepack@latest ; \
    npm install -g gulp-cli@latest ; \
    npm install -g webpack-cli@latest ; \
    corepack enable ; \
    yarn config set strict-ssl false -g ; \
    apt clean ; apt update ; apt upgrade -y ; \
    apt-file update ; \
    pbuilder clean
COPY base.tgz /var/cache/pbuilder/
COPY build.sh /
CMD ["/bin/sh","-c","/build.sh"]
