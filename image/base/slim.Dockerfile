# NAME:     discourse/base
# VERSION:  release

ARG DEBIAN_RELEASE=bookworm
FROM discourse/ruby:3.3.4-${DEBIAN_RELEASE}-slim

ARG DEBIAN_RELEASE
ENV PG_MAJOR=13 \
    RUBY_ALLOCATOR=/usr/lib/libjemalloc.so \
    LEFTHOOK=0 \
    DEBIAN_RELEASE=${DEBIAN_RELEASE} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

ADD install-imagemagick /tmp/install-imagemagick
ADD install-jemalloc /tmp/install-jemalloc
# From https://nginx.org/en/pgp_keys.html
ADD nginx_public_keys.key /tmp/nginx_public_keys.key
ADD install-nginx /tmp/install-nginx
ADD install-oxipng /tmp/install-oxipng
ADD install-redis /tmp/install-redis
# This tool allows us to disable huge page support for our current process
# since the flag is preserved through forks and execs it can be used on any
# process
ADD thpoff.c /src/thpoff.c

RUN set -eux; \
    # Ensures that the gid and uid of the following users are consistent to avoid permission issues on directories in the
    # mounted volumes.
    groupadd --gid 104 postgres; \
    useradd --uid 101 --gid 104 --home /var/lib/postgresql --shell /bin/bash -c "PostgreSQL administrator,,," postgres; \
    groupadd --gid 106 redis; \
    useradd --uid 103 --gid 106 --home /var/lib/redis --shell /usr/sbin/nologin redis; \
    groupadd --gid 1000 discourse; \
    useradd --uid 1000 --gid 1000 -m --shell /bin/bash discourse; \
    \
    echo 2.0.`date +%Y%m%d` > /VERSION; \
    echo "deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-backports main" > "/etc/apt/sources.list.d/${DEBIAN_RELEASE}-backports.list"; \
    echo "debconf debconf/frontend select Teletype" | debconf-set-selections; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends sudo curl; \
    install -d /usr/share/postgresql-common/pgdg; \
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${DEBIAN_RELEASE}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    curl --silent --location https://deb.nodesource.com/setup_18.x | sudo bash -; \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -; \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list; \
    apt-mark hold initscripts; \
    apt-get update; \
    apt-get -y upgrade; \
    \
    # Dependencies required to run Discourse
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        locales \
        locales-all \
        git \
        rsyslog \
        logrotate \
        cron \
        ssh-client \
        less \
        ca-certificates \
        rsync \
        libxslt-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libyaml-dev \
        libtool \
        libpcre3 \
        libpcre3-dev \
        zlib1g \
        zlib1g-dev \
        libxml2-dev \
        gawk \
        parallel \
        postgresql-${PG_MAJOR} \
        postgresql-client \
        postgresql-contrib-${PG_MAJOR} \
        libpq-dev \
        postgresql-${PG_MAJOR}-pgvector \
        libreadline-dev \
        anacron \
        psmisc \
        whois \
        brotli \
        libunwind-dev \
        libtcmalloc-minimal4 \
        ripgrep \
        poppler-utils \
        runit \
        socat \
        nodejs \
        yarn \
        # START Nginx
        nginx-common \
        # END Nginx
        # START ImageMagick
        pngcrush \
        pngquant \
        libde265-0 \
        libde265-dev \
        libjpeg62-turbo \
        libjpeg62-turbo-dev \
        libwebp7 \
        x265 \
        libx265-dev \
        libtool \
        libpng16-16 \
        libpng-dev \
        libwebp-dev \
        libgomp1 \
        libwebpmux3 \
        libwebpdemux2 \
        ghostscript \
        libxml2-dev \
        libxml2-utils \
        librsvg2-dev \
        libltdl7-dev \
        libbz2-dev \
        gsfonts \
        libtiff-dev \
        libfreetype6-dev \
        libjpeg-dev \
        libheif1 \
        libheif-dev \
        libaom-dev \
        # END ImageMagick
    ; \
    savedAptMark="$(apt-mark showmanual)"; \
    # Dependencies required to build packages. These packages are automatically removed
    # at the end of the RUN step.
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
        wget \
        gcc \
        g++ \
        make \
        cmake \
        autoconf \
        automake \
        libtool \
        pkg-config \
        autoconf \
        yasm \
    ; \
    sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron; \
    sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf; \
    sed -i.bak 's/module(load="imklog")/#module(load="imklog")/' /etc/rsyslog.conf; \
    dpkg-divert --local --rename --add /sbin/initctl; \
    sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl"; \
    mkdir -p /etc/runit/1.d; \
    rm -f /etc/apt/apt.conf.d/40proxy; \
    locale-gen en_US; \
    npm install -g terser uglify-js pnpm; \
    \
    # Installs ImageMagick
    /tmp/install-imagemagick; \
    # Installs JeMalloc
    /tmp/install-jemalloc; \
    \
    # Installs Nginx
    gpg --import /tmp/nginx_public_keys.key; \
    rm /tmp/nginx_public_keys.key; \
    /tmp/install-nginx; \
    # Installs Redis
    /tmp/install-redis; \
    # Installs Oxipng
    /tmp/install-oxipng; \
    echo 'gem: --no-document' >> /usr/local/etc/gemrc; \
    gem update --system; \
    gem install pups --force; \
    mkdir -p /pups/bin/; \
    ln -s /usr/local/bin/pups /pups/bin/pups; \
    gcc -o /usr/local/sbin/thpoff /src/thpoff.c && rm /src/thpoff.c; \
    \
    # Discourse specific bits
    install -dm 0755 -o discourse -g discourse /var/www/discourse; \
    sudo -u discourse git clone --filter=tree:0 https://github.com/discourse/discourse.git /var/www/discourse; \
    gem install bundler --conservative -v $(awk '/BUNDLED WITH/ { getline; gsub(/ /,""); print $0 }' /var/www/discourse/Gemfile.lock); \
    \
    # Clean up
    rm -fr /usr/share/man; \
    rm -fr /usr/share/doc; \
    rm -fr /usr/share/vim/vim74/doc; \
    rm -fr /usr/share/vim/vim74/lang; \
    rm -fr /usr/share/vim/vim74/spell/en*; \
    rm -fr /usr/share/vim/vim74/tutor; \
    rm -fr /usr/local/share/doc; \
    rm -fr /usr/local/share/ri; \
    rm -fr /var/lib/apt/lists/*; \
    rm -fr /root/.gem; \
    rm -fr /root/.npm; \
    rm -fr /tmp/*; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
      | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
      | sort -u \
      | xargs -r dpkg-query --search \
      | cut -d: -f1 \
      | sort -u \
      | xargs -r apt-mark manual \
      ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get clean; \
    \
    # this is required for aarch64 which uses buildx
    # see https://github.com/docker/buildx/issues/150
    rm -f /etc/service

COPY etc/ /etc
COPY sbin/ /sbin
